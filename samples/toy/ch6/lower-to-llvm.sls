;; Toy Ch6 — full lowering to LLVM dialect.
;; Mirrors mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp
;;
;; Lowers the combination of Affine+SCF+Arith+Func+MemRef dialects to the
;; LLVM dialect. toy.print is silenced (kept as dynamically legal) since the
;; full printf lowering requires additional SCF+LLVM work.
(library (toy ch6 lower-to-llvm)
  (export %%toy-to-llvm-lower!)
  (import (except (rnrs) =)
          (mlir IR MLIRContext)
          (mlir IR Operation)
          (mlir IR BuiltinOps)
          (mlir Pass PassManager)
          (mlir Transforms Passes)
          (mlir Dialect LLVMIR IR LLVMDialect)
          (mlir Dialect LLVMIR Transforms Passes)
          (mlir Conversion LLVMCommon TypeConverter)
          (mlir Conversion AffineToStandard AffineToStandard)
          (mlir Conversion SCFToControlFlow SCFToControlFlow)
          (mlir Conversion ArithToLLVM ArithToLLVM)
          (mlir Conversion MemRefToLLVM MemRefToLLVM)
          (mlir Conversion ControlFlowToLLVM ControlFlowToLLVM)
          (mlir Conversion FuncToLLVM ConvertFuncToLLVM)
          (mlir Transforms DialectConversion)
          (mlir IR PatternMatch)
          (crest))

  ;; Perform full lowering to LLVM dialect on module-op.
  ;; toy.print is kept as dynamically legal (silenced).
  (define (%%toy-to-llvm-lower! module-op ctx)
    (with-LLVMTypeConverter (tc ctx)
                            (with-ConversionTarget (target ctx)
                              ;; LLVM dialect is legal; builtin.module and unrealized casts also.
                              (target-add-legal-dialect target "llvm")
                              (target-add-legal-op target ctx "builtin.unrealized_conversion_cast")
                              (target-add-legal-op target ctx "builtin.module")
                              ;; toy.print is kept as dynamically legal — silenced at this level.
                              (target-add-dynamically-legal-op target ctx "toy.print"
                                                               (lambda (op) #t))
                              (with-RewritePatternSet (patterns ctx)
                                ;; Populate all dialect-to-LLVM conversion patterns.
                                (mlir::populateAffineToStdConversionPatterns patterns)
                                (mlir::populateSCFToControlFlowConversionPatterns patterns)
                                (mlir::arith::populateArithToLLVMConversionPatterns tc patterns)
                                (mlir::populateFinalizeMemRefToLLVMConversionPatterns tc patterns)
                                (mlir::cf::populateControlFlowToLLVMConversionPatterns tc patterns)
                                (mlir::populateFuncToLLVMConversionPatterns tc patterns)
                                ;; Full conversion — toy.print stays (dynamically legal above).
                                (apply-full-conversion module-op target patterns)))))

  ) ;; end library (toy ch6 lower-to-llvm)
