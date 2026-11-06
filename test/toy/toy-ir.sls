;; Test driver for scheme-mlir: loads a chapter's toy dialect, parses the MLIR text in <input.mlir>,
;; runs a pass (the pass manager verifies the module first) and prints the module. The Toy
;; chapters have no tool that reads MLIR text, so the tests that need one use this.
;;
;; Usage: scheme-mlir toy-ir.sls <toy/chN/toy> <input.mlir> <verify|inline>
;;   verify  run the canonicalizer, which only matters because the verifier runs
;;   inline  run MLIR's inliner with the verifier off: the toy dialect cannot mark toy.return
;;           as a terminator before LLVM 23 (see lib/Crest/TraitStub.cpp), so verification would fail
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation)
        (mlir Pass PassManager) (mlir Transforms Passes) (mlir Transforms InliningUtils))

(let* ([args    (command-line-arguments)]
       [dialect (car args)]
       [file    (cadr args)]
       [mode    (caddr args)])
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" dialect)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      (let ([module-op (mlir::parseSourceFile ctx file)])
        (unless (and module-op (not (zero? module-op)))
          (display "parse failed\n")
          (exit 1))
        (with-PassManager pm (ctx)
          (when (string=? mode "inline")
            (mlir::PassManager::enableVerifier pm #f))
          (mlir::PassManager::addPass pm (if (string=? mode "inline")
                                             (mlir::createInlinerPass)
                                             (mlir::createCanonicalizerPass)))
          (unless (mlir::PassManager::run! pm module-op)
            (display "pass manager failed\n")
            (exit 1)))
        (display (mlir::Operation::print module-op))
        (newline)))))
