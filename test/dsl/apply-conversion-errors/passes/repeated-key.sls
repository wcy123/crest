#!r6rs
(library (passes repeated-key)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (crest))

  (define-pass-entry-point (module-op)
    (apply-conversion module-op (mlir::Operation::getContext module-op)
                      :legal-dialects ("func") :legal-dialects ("builtin")))

  ) ;; end library
