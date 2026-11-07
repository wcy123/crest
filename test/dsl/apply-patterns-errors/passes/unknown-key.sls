#!r6rs
(library (passes unknown-key)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (crest))

  (define (run-pass module-op)
    (apply-patterns module-op (mlir::Operation::getContext module-op) :pattern (("a" f))))

  ) ;; end library
