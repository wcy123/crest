#!r6rs
;; Mirrors mlir/IR/Attributes.h
;;
;; A NamedAttribute is the pair of a name and a value that MLIR gives a verifier of a dialect
;; (:verify-op-attr, :verify-region-arg-attr, :verify-region-result-attr).
(library (mlir IR Attributes)
  (export mlir::NamedAttribute::getName
          mlir::NamedAttribute::getValue
          mlir::Attribute::print)
  (import (rnrs)
          (mlir IR Attributes ffi))

  (define mlir::NamedAttribute::getName %mlir::NamedAttribute::getName)

  (define mlir::NamedAttribute::getValue %mlir::NamedAttribute::getValue)

  (define mlir::Attribute::print %mlir::Attribute::print)

  ) ;; end library (mlir IR Attributes)
