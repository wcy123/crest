#!r6rs
(library (passes bad-dynamic)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (crest))

  (define (run-pass module-op)
    (apply-conversion module-op (mlir::Operation::getContext module-op)
                      :dynamically-legal (("toy.print"))))

  ) ;; end library
