#!r6rs
(library (passes bad-set-entry)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (crest))

  (define-pattern-set broken ("a"))
  (define-pass-entry-point (module-op)
    #t)

  ) ;; end library
