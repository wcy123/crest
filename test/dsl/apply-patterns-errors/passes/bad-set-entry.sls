#!r6rs
(library (passes bad-set-entry)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (crest))

  (define-pattern-set broken ("a"))
  (define (run-pass module-op)
    #t)

  ) ;; end library
