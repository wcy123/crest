;; Test driver for scheme-mlir: loads a chapter's toy dialect, parses the MLIR text in <input.mlir>,
;; runs a pass (the pass manager verifies the module first) and prints the module. The Toy
;; chapters have no tool that reads MLIR text, so the tests that need one use this.
;;
;; Usage: scheme-mlir toy-ir.sls <toy/chN/toy> <input.mlir> verify
;;   verify  run the canonicalizer, which only matters because the verifier runs
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation)
        (mlir Pass PassManager) (mlir Transforms Passes))

(let* ([args    (command-line-arguments)]
       [dialect (car args)]
       [file    (cadr args)])
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" dialect)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      (let ([module-op (mlir::parseSourceFile ctx file)])
        (unless (and module-op (not (zero? module-op)))
          (display "parse failed\n")
          (exit 1))
        (with-PassManager pm (ctx)
          (mlir::PassManager::addPass pm (mlir::createCanonicalizerPass))
          (unless (mlir::PassManager::run! pm module-op)
            (display "pass manager failed\n")
            (exit 1)))
        (display (mlir::Operation::print module-op))
        (newline)))))
