;; scheme-mlir driver: parse the module in argv[1], run a pipeline of Scheme passes, print the module.
;; argv[2] is "ok" (a renaming pass nested on func.func, then a pass on the module) or "fail".
(import (except (rnrs) =)
        (only (chezscheme) command-line-arguments)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR BuiltinAttributes)
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

(define args (command-line-arguments))

(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::getOrLoadDialect ctx "func")
    (let ([op (mlir::parseSourceFile ctx (car args))])
      (with-PassManager pm (ctx)
        (if (string=? (cadr args) "ok")
            (begin
              (mlir::OpPassManager::addPass (mlir::PassManager::nest pm "func.func") (tag-functions))
              (mlir::PassManager::addPass pm (count-ops)))
            (mlir::PassManager::addPass pm (always-fail)))
        (cond
         [(mlir::PassManager::run! pm op)
          (display (mlir::Operation::print op))
          (display "passes ran: ") (display count) (newline)]
         [else (display "pipeline failed\n") (exit 1)])))))
