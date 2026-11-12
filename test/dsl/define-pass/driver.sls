;; scheme-mlir driver: parse the module in argv[1], run a pipeline of Scheme passes, print the module.
;; argv[2] is "ok" (a renaming pass nested on func.func, then a pass on the module), "fail", "reuse" (the
;; same define-pass in two pipelines, twice in one of them) or "raise" (a body that raises an error).
(import (except (rnrs) =)
        (only (chezscheme) command-line-arguments)
        (mlir IR DialectRegistry) (mlir IR MLIRContext)
        (mlir IR OwningOpRef) (mlir IR Operation) (mlir IR BuiltinAttributes)
        (mlir Dialect Func IR FuncOps)
        (mlir Pass PassManager)
        (crest pass))

;; Anchored where the PassManager puts it: tags each func.func with a pass number attribute.
(define-pass (tag-functions op)
  (mlir::Operation::setAttr! op "tagged" (mlir::StringAttr::get (mlir::Operation::getContext op) "yes"))
  #t)

;; Runs on the module: counts its functions and records the number.
(define count 0)
(define-pass (count-ops op)
  (set! count (+ count 1))
  #t)

(define-pass (always-fail op)
  (mlir::Operation::emitError op "pass always-fail: this module is not accepted")
  #f)

(define-pass (always-raise op)
  (error 'always-raise "this pass is broken"))

(define args (command-line-arguments))

;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it.
(define (%%quit code)
  (raise (list 'exit code)))

;; LEAK WARNING: what this makes (the context, the module, the builder) lives in a with- scope and is
;; freed when the scope ends. A raw MLIRContext::new, ModuleOp::create or parseSourceFile result that is
;; never freed leaked, and exit inside a scope skips the cleanup: raise, and exit at the top (%%quit).
(guard (e [(and (pair? e) (eq? (car e) 'exit)) (exit (cadr e))])
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "func")
      (with-mlir::OwningOpRef op (mlir::parseSourceFile ctx (car args))
        (with-PassManager pm (ctx)
          (cond
           [(string=? (cadr args) "ok")
            (mlir::OpPassManager::addPass (mlir::PassManager::nest pm "func.func") (tag-functions))
            (mlir::PassManager::addPass pm (count-ops))]
           [(string=? (cadr args) "reuse")
            (mlir::PassManager::addPass pm (count-ops))
            (mlir::PassManager::addPass pm (count-ops))]
           [(string=? (cadr args) "raise")
            (mlir::PassManager::addPass pm (always-raise))]
           [else (mlir::PassManager::addPass pm (always-fail))])
          (cond
           [(and (string=? (cadr args) "reuse")
                 (with-PassManager other (ctx)
                   (mlir::PassManager::addPass other (count-ops))
                   (mlir::PassManager::run! other op))
                 (mlir::PassManager::run! pm op))
            (display "passes ran: ") (display count) (newline)]
           [(string=? (cadr args) "reuse") (display "pipeline failed\n") (%%quit 1)]
           [(mlir::PassManager::run! pm op)
            (display (mlir::Operation::print op))
            (display "passes ran: ") (display count) (newline)]
           [else (display "pipeline failed\n") (%%quit 1)]))))))
