;; Toy Ch6 — full lowering to LLVM dialect.
;;
;; Lowers the combination of Affine+SCF+Arith+Func+MemRef+Toy dialects to the
;; LLVM dialect, including toy.print → printf calls via SCF loop nests, written with begin-mlir-code.
(library (toy ch6 lower-to-llvm)
  (export %%toy-to-llvm-lower!)
  (import (except (rnrs) =)
          (mlir IR MLIRContext)
          (only (mlir IR Operation)
                mlir::Operation::getLoc
                mlir::Operation::getContext
                mlir::Operation::getOperand
                mlir::Operation::getParentOfType<ModuleOp>)
          (mlir IR BuiltinOps)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Builders) with-InsertionGuard)
          (only (mlir IR BuiltinTypes)
                mlir::IndexType::get
                mlir::IntegerType::get<i8>
                mlir::IntegerType::get<i32>
                mlir::IntegerType::get<i64>
                mlir::MemRefType::getElementType
                mlir::ShapedType::getShape)
          (only (mlir IR BuiltinAttributes)
                mlir::StringAttr::get/len
                mlir::TypeAttr::get
                mlir::parseAttribute)
          (mlir Pass PassManager)
          (mlir Transforms Passes)
          (mlir Dialect LLVMIR IR LLVMDialect)
          (mlir Dialect LLVMIR IR LLVMOps)
          (mlir Dialect LLVMIR Transforms Passes)
          (mlir Conversion LLVMCommon TypeConverter)
          (mlir Conversion AffineToStandard AffineToStandard)
          (mlir Conversion SCFToControlFlow SCFToControlFlow)
          (mlir Conversion ArithToLLVM ArithToLLVM)
          (mlir Conversion MemRefToLLVM MemRefToLLVM)
          (mlir Conversion ControlFlowToLLVM ControlFlowToLLVM)
          (mlir Conversion FuncToLLVM ConvertFuncToLLVM)
          (only (mlir IR PatternMatch)
                mlir::RewriterBase::setInsertionPointToStart)
          (crest))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.print → printf calls inside an scf.for nest
  ;;===--------------------------------------------------------------------===;;

  ;; The type of printf: i32 (ptr, ...).
  (define (%%printf-type ctx)
    (mlir::LLVM::LLVMFunctionType::get ctx
                                       (mlir::IntegerType::get<i32> ctx)
                                       (mlir::LLVM::LLVMPointerType::get ctx)
                                       1))

  ;; Get-or-insert the @printf declaration at the start of the module. The insertion point
  ;; is restored when the guard ends.
  (define (%%get-or-insert-printf! rw module-op ctx)
    (if (not (zero? (mlir::ModuleOp::lookupSymbol module-op "printf")))
        (mlir::FlatSymbolRefAttr::get ctx "printf")
        (let ([fnty (%%printf-type ctx)]
              [body (mlir::ModuleOp::getBody module-op)])
          (with-InsertionGuard guard (rw)
                               (mlir::RewriterBase::setInsertionPointToStart rw body)
                               (with-current-OpBuilder rw
                                 (begin-mlir-code
                                     llvm.func ()
                                     (sym_name : "printf" :string)
                                     (function_type : (mlir::TypeAttr::get fnty))
                                     (linkage : (mlir::parseAttribute "#llvm.linkage<external>"))
                                     (CConv : (mlir::parseAttribute "#llvm.cconv<ccc>"))
                                     (:region)
                                     :loc (mlir::Operation::getLoc module-op))))
          (mlir::FlatSymbolRefAttr::get ctx "printf"))))

  ;; Get-or-create a global string constant at the start of the module; returns the global op.
  (define (%%get-or-create-global-string! rw loc name value module-op ctx)
    (let ([existing (mlir::ModuleOp::lookupSymbol module-op name)])
      (if (not (zero? existing))
          existing
          (let* ([len   (string-length value)]  ; includes embedded NUL
                 [arrty (mlir::LLVM::LLVMArrayType::get (mlir::IntegerType::get<i8> ctx) len)]
                 ;; Use get/len so embedded NUL bytes are preserved in the StringAttr.
                 [attr  (mlir::StringAttr::get/len ctx value len)]
                 [body  (mlir::ModuleOp::getBody module-op)])
            (with-InsertionGuard guard (rw)
                                 (mlir::RewriterBase::setInsertionPointToStart rw body)
                                 (with-current-OpBuilder rw
                                   (begin-mlir-code
                                       llvm.mlir.global ()
                                       (global_type : (mlir::TypeAttr::get arrty))
                                       (constant : #f :unit)
                                       (sym_name : name :string)
                                       (linkage : (mlir::parseAttribute "#llvm.linkage<internal>"))
                                       (value : attr)
                                       (:region)
                                       :loc loc)))))))

  ;; Get-or-create a global string and return a GEP to its first char, emitted at the
  ;; current insertion point.
  (define (%%global-string-ptr! rw loc name value module-op ctx)
    (let* ([global (%%get-or-create-global-string! rw loc name value module-op ctx)]
           [ptr    (mlir::LLVM::LLVMPointerType::get ctx)]
           [i64    (mlir::IntegerType::get<i64> ctx)]
           [arrty  (mlir::LLVM::GlobalOp::getType global)])
      (begin-mlir-code
          addr = llvm.mlir.addressof ()
          (global_name : (mlir::FlatSymbolRefAttr::get ctx name))
          :loc loc -> ptr
          zero = llvm.mlir.constant () (value : 0 :i64) :loc loc -> i64
          gep  = llvm.getelementptr (addr zero zero)
          (rawConstantIndices : '(-2147483648 -2147483648) :i32-array)
          (elem_type : (mlir::TypeAttr::get arrty))
          :loc loc -> ptr)))

  ;; Call printf with args, at the ambient builder.
  (define (%%call-printf! loc ctx printf-ref args)
    (let ([fnty (%%printf-type ctx)]
          [i32  (mlir::IntegerType::get<i32> ctx)])
      (begin-mlir-code
          ret = llvm.call (,@args)
          (callee : printf-ref)
          (var_callee_type : (mlir::TypeAttr::get fnty))
          (operandSegmentSizes : (list (length args) 0) :i32-array)
          (op_bundle_sizes : '() :i32-array)
          :loc loc -> i32)))

  ;; Emit an scf.for nest over shape; the innermost body loads one element of in and calls
  ;; printf with fmt, and each loop except the innermost prints nl after its body. The ops go
  ;; to the ambient builder; each loop body is a ^bb, so its ops land inside the loop.
  (define (%%emit-print-nest! loc ctx printf-ref fmt nl in shape)
    (let ([idx  (mlir::IndexType::get ctx)]
          [elem-type (mlir::MemRefType::getElementType (mlir::Value::getType in))])
      (let nest ([dims shape] [ivs '()])
        (if (null? dims)
            (begin-mlir-code
                elem = memref.load (in ,@(reverse ivs)) :loc loc -> elem-type
                (%%call-printf! loc ctx printf-ref (list fmt elem)))
            (begin-mlir-code
                lb = arith.constant () (value : 0 :index) :loc loc -> idx
                ub = arith.constant () (value : (car dims) :index) :loc loc -> idx
                st = arith.constant () (value : 1 :index) :loc loc -> idx
                scf.for (lb ub st)
                (^body ((iv : idx))
                       (nest (cdr dims) (cons iv ivs))
                       (when (pair? (cdr dims))
                         (%%call-printf! loc ctx printf-ref (list nl)))
                       scf.yield () :loc loc)
                :loc loc)))))

  ;; Lower toy.print → scf.for loops calling @printf on each element. The original operand
  ;; is read from the op, not from the converted operands: the loops index the memref and the
  ;; shape is read from its type.
  (define-conversion-pattern (%%print-lower! op operands-ref rw tc)
    :if-match
      toy.print (_)
    :then-let
      ([loc        (mlir::Operation::getLoc op)]
       [in         (mlir::Operation::getOperand op 0)]
       [ctx        (mlir::Operation::getContext op)]
       [module-op  (mlir::Operation::getParentOfType<ModuleOp> op)]
       [shape      (mlir::ShapedType::getShape (mlir::Value::getType in))]
       [printf-ref (%%get-or-insert-printf! rw module-op ctx)])
    :rewrite op :with
      fmt = (%%global-string-ptr! rw loc "frmt_spec" "%f \x00;" module-op ctx)
      nl  = (%%global-string-ptr! rw loc "nl" "\n\x00;" module-op ctx)
      (%%emit-print-nest! loc ctx printf-ref fmt nl in shape))

  ;;===--------------------------------------------------------------------===;;
  ;; LLVM lowering pass
  ;;===--------------------------------------------------------------------===;;

  ;; Perform full lowering to LLVM dialect on module-op.
  (define (%%toy-to-llvm-lower! module-op ctx)
    (apply-conversion module-op ctx
                      :type-converter llvm
                      ;; LLVM dialect is legal; builtin.module too. Toy is illegal: everything must lower.
                      :legal-dialects ("llvm")
                      :legal-ops ("builtin.module")
                      :illegal-dialects ("toy")
                      ;; toy.print → printf loop nest. No TypeConverter: the pattern reads the original
                      ;; memref operand types directly.
                      :patterns (("toy.print" %%print-lower! :no-type-converter))
                      ;; All dialect-to-LLVM conversion patterns.
                      :populate (lambda (tc patterns)
                                  (mlir::populateAffineToStdConversionPatterns patterns)
                                  (mlir::populateSCFToControlFlowConversionPatterns patterns)
                                  (mlir::arith::populateArithToLLVMConversionPatterns tc patterns)
                                  (mlir::populateFinalizeMemRefToLLVMConversionPatterns tc patterns)
                                  (mlir::cf::populateControlFlowToLLVMConversionPatterns tc patterns)
                                  (mlir::populateFuncToLLVMConversionPatterns tc patterns))))

  ) ;; end library (toy ch6 lower-to-llvm)
