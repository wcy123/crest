;; Test driver for scheme-mlir: loads a chapter's toy dialect, parses the MLIR text in <input.mlir>,
;; runs a pass (the pass manager verifies the module first) and prints the module. The Toy
;; chapters have no tool that reads MLIR text, so the tests that need one use this.
;;
;; Usage: scheme-mlir toy-ir.sls <toy/chN/toy> <input.mlir> verify
;;   verify  verify the module (the parser does not), then run the inliner, which has nothing to
;;           inline, so the pass manager's own verification runs too
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext)
        (mlir IR OwningOpRef) (mlir IR Operation)
        (mlir Pass PassManager) (mlir Transforms Passes) (mlir Transforms InliningUtils))

;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it.
(define (%%quit code)
  (raise (list 'exit code)))

;; LEAK WARNING: what this makes (the context, the module, the builder) lives in a with- scope and is
;; freed when the scope ends. A raw MLIRContext::new, ModuleOp::create or parseSourceFile result that is
;; never freed leaked, and exit inside a scope skips the cleanup: raise, and exit at the top (%%quit).
(guard (e [(and (pair? e) (eq? (car e) 'exit)) (exit (cadr e))])
  (let* ([args    (command-line-arguments)]
         [dialect (car args)]
         [file    (cadr args)])
    (with-DialectRegistry reg ()
      (mlir::DialectRegistry::insert reg "toy" dialect)
      (with-MLIRContext ctx (reg)
        (mlir::MLIRContext::getOrLoadDialect ctx "toy")
        (with-mlir::OwningOpRef module-op (mlir::parseSourceFile ctx file)
          (unless (and module-op (not (zero? module-op)))
            (display "parse failed\n")
            (%%quit 1))
          (unless (mlir::Operation::verify? module-op)
            (display "verification failed\n")
            (%%quit 1))
          (with-PassManager pm (ctx)
            (mlir::PassManager::addPass pm (mlir::createInlinerPass))
            (unless (mlir::PassManager::run! pm module-op)
              (display "pass manager failed\n")
              (%%quit 1)))
          (display (mlir::Operation::print module-op))
          (newline))))))
