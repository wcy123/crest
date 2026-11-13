#!r6rs
;; apply-conversion with :type-converter llvm and :configure-type-converter: the LLVM type converter is made for
;; you, and nothing would run the configuration.
(library (passes llvm-configure)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (crest))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-conversion module-op ctx
                          :type-converter llvm
                          :configure-type-converter (lambda (tc) #t)
                          :patterns ())))))
