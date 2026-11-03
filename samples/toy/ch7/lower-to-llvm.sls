;; Toy Ch7 — full lowering to LLVM dialect.
;; Mirrors mlir/examples/toy/Ch7/mlir/LowerToLLVM.cpp
;;
;; Lowers the combination of Affine+SCF+Arith+Func+MemRef+Toy dialects to the
;; LLVM dialect, including toy.print → printf calls via SCF loop nests.
(library (toy ch7 lower-to-llvm)
  (export %%toy-to-llvm-lower!)
  (import (except (rnrs) =)
          (mlir IR MLIRContext)
          (only (mlir IR Operation)
                mlir::Operation::getLoc
                mlir::Operation::getContext
                mlir::Operation::getOperand
                mlir::Operation::getParentOfType<ModuleOp>)
          (only (mlir IR Builders) crest::as_ptr<mlir::OpBuilder>)
          (mlir IR BuiltinOps)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Block) mlir::Block::front)
          (only (mlir IR BuiltinTypes)
                mlir::IntegerType::get<i8>
                mlir::IntegerType::get<i32>
                mlir::ShapedType::getShape)
          (only (mlir IR BuiltinAttributes)
                mlir::StringAttr::get/len)
          (mlir Pass PassManager)
          (mlir Transforms Passes)
          (mlir Dialect LLVMIR IR LLVMDialect)
          (mlir Dialect LLVMIR IR LLVMOps)
          (mlir Dialect LLVMIR Transforms Passes)
          (mlir Dialect SCF IR SCFOps)
          (mlir Dialect Arith IR Arith)
          (mlir Dialect MemRef IR MemRef)
          (mlir Conversion LLVMCommon TypeConverter)
          (mlir Conversion AffineToStandard AffineToStandard)
          (mlir Conversion SCFToControlFlow SCFToControlFlow)
          (mlir Conversion ArithToLLVM ArithToLLVM)
          (mlir Conversion MemRefToLLVM MemRefToLLVM)
          (mlir Conversion ControlFlowToLLVM ControlFlowToLLVM)
          (mlir Conversion FuncToLLVM ConvertFuncToLLVM)
          (only (mlir Transforms DialectConversion)
                target-add-legal-dialect
                target-add-legal-op
                target-add-illegal-dialect
                apply-full-conversion
                add-conversion-pattern/ctx
                with-ConversionTarget)
          (only (mlir IR PatternMatch)
                mlir::RewriterBase::eraseOp
                mlir::RewriterBase::setInsertionPoint
                mlir::RewriterBase::setInsertionPointToStart
                mlir::RewriterBase::setInsertionPointToEnd
                with-RewritePatternSet)
          (crest))

  ;;===--------------------------------------------------------------------===;;
  ;; Helpers for toy.print → printf lowering
  ;;===--------------------------------------------------------------------===;;

  ;; Get-or-insert @printf declaration in the module.
  ;; Temporarily moves rw IP to module body start; caller must restore IP afterward.
  (define (%%get-or-insert-printf! rw bld module-op ctx)
    (if (not (zero? (mlir::ModuleOp::lookupSymbol module-op "printf")))
        (mlir::FlatSymbolRefAttr::get ctx "printf")
        (let* ([i32ty (mlir::IntegerType::get<i32> ctx)]
               [ptrty (mlir::LLVM::LLVMPointerType::get ctx)]
               [fnty  (mlir::LLVM::LLVMFunctionType::get ctx i32ty ptrty 1)]
               [body  (mlir::ModuleOp::getBody module-op)])
          (mlir::RewriterBase::setInsertionPointToStart rw body)
          (mlir::LLVM::LLVMFuncOp::create bld (mlir::Operation::getLoc module-op) "printf" fnty)
          (mlir::FlatSymbolRefAttr::get ctx "printf"))))

  ;; Get-or-create a global string constant; returns the global op.
  ;; Temporarily moves rw IP to module body start; caller must restore IP afterward.
  (define (%%get-or-create-global-string! rw bld loc name value module-op ctx)
    (let ([existing (mlir::ModuleOp::lookupSymbol module-op name)])
      (if (not (zero? existing))
          existing
          (let* ([len   (string-length value)]  ; includes embedded NUL
                 [i8ty  (mlir::IntegerType::get<i8> ctx)]
                 [arrty (mlir::LLVM::LLVMArrayType::get i8ty len)]
                 ;; Use get/len so embedded NUL bytes are preserved in the StringAttr.
                 [attr  (mlir::StringAttr::get/len ctx value len)]
                 [body  (mlir::ModuleOp::getBody module-op)])
            (mlir::RewriterBase::setInsertionPointToStart rw body)
            (mlir::LLVM::GlobalOp::create bld loc arrty 1 8 name attr)))))

  ;; Get-or-create a global string and return GEP to its first char.
  ;; Restores rw IP to op after module-level insertions.
  (define (%%global-string-ptr! rw bld loc name value module-op ctx op)
    (let* ([global (%%get-or-create-global-string! rw bld loc name value module-op ctx)])
      ;; Restore IP to just before op so loop-body ops go in the right place.
      (mlir::RewriterBase::setInsertionPoint rw op)
      (let* ([ptrty (mlir::LLVM::LLVMPointerType::get ctx)]
             [arrty (mlir::LLVM::GlobalOp::getType global)]
             [addr  (mlir::LLVM::AddressOfOp::create bld loc global)]
             [c0    (mlir::LLVM::ConstantOp::create<i64> bld loc 0)])
        (mlir::LLVM::GEPOp::create bld loc ptrty arrty addr c0 c0))))

  ;; Lower toy.print → SCF loops calling @printf on each element.
  ;; Called via add-conversion-pattern/ctx (no TypeConverter) so operands are
  ;; the original unconverted values; tc arg is 0 (unused).
  (define (%%print-lower! op operands-ref rw tc)
    (let* ([bld       (crest::as_ptr<mlir::OpBuilder> rw)]
           [loc       (mlir::Operation::getLoc op)]
           [ctx       (mlir::Operation::getContext op)]
           [module-op (mlir::Operation::getParentOfType<ModuleOp> op)]
           ;; Get original memref type (operand before conversion)
           [orig-in   (mlir::Operation::getOperand op 0)]
           [mtype     (mlir::Value::getType orig-in)]
           [shape     (mlir::ShapedType::getShape mtype)]
           ;; Declare @printf; inserts at module start and leaves IP there.
           [printf-ref (%%get-or-insert-printf! rw bld module-op ctx)]
           ;; Create global format strings; each restores IP to op afterward.
           [fmt-val  (%%global-string-ptr! rw bld loc "frmt_spec" "%f \x00;" module-op ctx op)]
           [nl-val   (%%global-string-ptr! rw bld loc "nl" "\n\x00;" module-op ctx op)]
           ;; printf function type for calls
           [i32ty    (mlir::IntegerType::get<i32> ctx)]
           [ptrty    (mlir::LLVM::LLVMPointerType::get ctx)]
           [fnty     (mlir::LLVM::LLVMFunctionType::get ctx i32ty ptrty 1)]
           [in       orig-in])
      ;; Build nested SCF for loops over the memref shape
      (let loop ([dims shape] [dim-idx 0] [ivs '()])
        (if (null? dims)
            ;; Innermost: load element and call printf
            (let* ([elem (mlir::memref::LoadOp::create bld loc in (reverse ivs))]
                   [_ (mlir::LLVM::CallOp::create bld loc fnty printf-ref
                                                  (list fmt-val elem))])
              'done)
            ;; Emit scf.for for this dimension
            (let* ([lb   (mlir::arith::ConstantIndexOp::create bld loc 0)]
                   [ub   (mlir::arith::ConstantIndexOp::create bld loc (car dims))]
                   [step (mlir::arith::ConstantIndexOp::create bld loc 1)]
                   [for-op (mlir::scf::ForOp::create bld loc lb ub step)]
                   [body   (mlir::scf::ForOp::getBody for-op)]
                   [iv     (mlir::scf::ForOp::getInductionVar for-op)])
              ;; Remove default yield from body
              (mlir::RewriterBase::eraseOp rw (mlir::Block::front body))
              ;; Set insertion to body start
              (mlir::RewriterBase::setInsertionPointToEnd rw body)
              ;; Between outer dims: newline
              (when (not (null? (cdr dims)))
                (mlir::LLVM::CallOp::create bld loc fnty printf-ref (list nl-val)))
              ;; Recurse into inner dims
              (mlir::RewriterBase::setInsertionPointToStart rw body)
              (loop (cdr dims) (+ dim-idx 1) (cons iv ivs))
              ;; Emit yield
              (mlir::RewriterBase::setInsertionPointToEnd rw body)
              (mlir::scf::YieldOp::create bld loc))))
      (mlir::RewriterBase::eraseOp rw op)
      #t))

  ;;===--------------------------------------------------------------------===;;
  ;; LLVM lowering pass
  ;;===--------------------------------------------------------------------===;;

  ;; Perform full lowering to LLVM dialect on module-op.
  (define (%%toy-to-llvm-lower! module-op ctx)
    (with-LLVMTypeConverter (tc ctx)
      (with-ConversionTarget (target ctx)
        ;; LLVM dialect is legal; builtin.module too.
        (target-add-legal-dialect target "llvm")
        (target-add-legal-op target ctx "builtin.module")
        ;; Toy dialect is illegal — everything must be lowered.
        (target-add-illegal-dialect target "toy")
        (with-RewritePatternSet (patterns ctx)
          ;; Populate all dialect-to-LLVM conversion patterns.
          (mlir::populateAffineToStdConversionPatterns patterns)
          (mlir::populateSCFToControlFlowConversionPatterns patterns)
          (mlir::arith::populateArithToLLVMConversionPatterns tc patterns)
          (mlir::populateFinalizeMemRefToLLVMConversionPatterns tc patterns)
          (mlir::cf::populateControlFlowToLLVMConversionPatterns tc patterns)
          (mlir::populateFuncToLLVMConversionPatterns tc patterns)
          ;; toy.print → printf loop nest.
          ;; No TypeConverter: pattern reads original memref operand types directly.
          (add-conversion-pattern/ctx patterns "toy.print" %%print-lower! 1)
          ;; Full conversion — everything must lower.
          (apply-full-conversion module-op target patterns)))))

  ) ;; end library (toy ch7 lower-to-llvm)
