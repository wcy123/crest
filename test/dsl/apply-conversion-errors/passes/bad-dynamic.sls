#!r6rs
(library (passes bad-dynamic)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (crest))

  (define-pass-entry-point (module-op)
    (apply-conversion module-op (mlir::Operation::getContext module-op)
                      :dynamically-legal (("toy.print"))))

  ) ;; end library
