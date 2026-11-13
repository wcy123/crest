#!r6rs
;; Mirrors mlir/IR/Attributes.h
(library (mlir IR Attributes ffi)
  (export %mlir::NamedAttribute::getName
          %mlir::NamedAttribute::getValue
          %mlir::Attribute::print)
  (import (chezscheme)
          (crest support foreign))

  ;; (uptr named) -> uptr: the StringAttr that names the attribute.
  (define %mlir::NamedAttribute::getName
    (crest-foreign-procedure "mlir::NamedAttribute::getName" (uptr) uptr))

  ;; (uptr named) -> uptr: the value of the attribute.
  (define %mlir::NamedAttribute::getValue
    (crest-foreign-procedure "mlir::NamedAttribute::getValue" (uptr) uptr))

  ;; (uptr attribute) -> string: the attribute as MLIR prints it.
  (define %mlir::Attribute::print
    (crest-foreign-procedure "mlir::Attribute::print" (uptr) scheme-object))

  ) ;; end library (mlir IR Attributes ffi)
