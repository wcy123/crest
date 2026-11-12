#!r6rs
;; The two ways a Scheme program loads a Scheme dialect: load-scheme-dialect! into a context, and
;; mlir::DialectRegistry::insert into a registry. A library that does not load raises a Scheme error that
;; names it, instead of aborting the process.
(import (rnrs)
        (only (chezscheme) display-condition)
        (mlir IR MLIRContext)
        (mlir IR DialectRegistry)
        (crest dialect))

(define (try who thunk)
  ;; LEAK WARNING: what this makes (the context, the module, the builder) lives in a with- scope and is
  ;; freed when the scope ends. A raw MLIRContext::new, ModuleOp::create or parseSourceFile result that is
  ;; never freed leaked, and exit inside a scope skips the cleanup: raise, and exit at the top (%%quit).
  (guard (e [#t (display who) (display ": ") (display-condition e) (newline)])
    (thunk)
    (display who) (display ": loaded") (newline)))

(try "load-scheme-dialect!"
     (lambda ()
       (with-DialectRegistry reg ()
         (with-MLIRContext ctx (reg)
           (load-scheme-dialect! ctx "bad" "passes/body-error")))))
(try "DialectRegistry::insert"
     (lambda ()
       (with-DialectRegistry reg ()
         (mlir::DialectRegistry::insert reg "bad" "passes/body-error"))))
