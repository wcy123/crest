#!r6rs
(library (passes bad-mode)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (crest))

  (define-pass-entry-point (module-op)
    (apply-conversion module-op (mlir::Operation::getContext module-op)
                      :partial-mode :full-mode))

  ) ;; end library
