;; scheme-mlir driver: a context loads a Scheme dialect, which sets current-MLIRContext (C++ drives that load and sets
;; the parameter, so that the callables of the dialect can report errors in it). The parameter holds a bare pointer,
;; so it must not outlive the context: when the context goes, the dialect makes the parameter #f again.
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext)
        (crest dialect))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (display "before the load: ")
    (display (current-MLIRContext))
    (newline)
    (load-scheme-dialect! ctx "hkv" "passes/hk-verify")
    (display "after the load: ")
    (display (if (current-MLIRContext) "a context" "#f"))
    (newline)))

(display "after the context: ")
(display (current-MLIRContext))
(newline)
