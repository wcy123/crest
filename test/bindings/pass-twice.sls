;; scheme-mlir driver: adds the same pass to a pass manager twice. A pass manager owns the passes that it is
;; given, so the second add would give the pass two owners, and both would free it (a double free when the
;; manager ends). The second add must be an error. argv[1] is the case.
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext)
        (mlir Pass PassManager)
        (crest pass))

(define-pass (noop op) #t)

(define (try thunk)
  (guard (e [#t (display (if (who-condition? e) (condition-who e) "?"))
                (display ": ")
                (display (if (message-condition? e) (condition-message e) e))
                (newline)])
    (thunk)
    (display "no error")
    (newline)))

(define name (car (command-line-arguments)))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (with-PassManager pm (ctx)
      (cond
       [(string=? name "root")
        (let ([pass (noop)])
          (mlir::PassManager::addPass pm pass)
          (try (lambda () (mlir::PassManager::addPass pm pass))))]
       [(string=? name "nested")
        (let ([nested (mlir::PassManager::nest pm "func.func")]
              [pass (noop)])
          (mlir::OpPassManager::addPass nested pass)
          (try (lambda () (mlir::OpPassManager::addPass nested pass))))]
       [(string=? name "two-passes")
        ;; Two different passes are fine.
        (mlir::PassManager::addPass pm (noop))
        (try (lambda () (mlir::PassManager::addPass pm (noop))))]))))
