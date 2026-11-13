#!r6rs
;; Mirrors mlir/Dialect/SCF/IR/SCFDialect.h
(library (mlir Dialect SCF IR SCFDialect ffi)
  (export %mlir::DialectRegistry::insert<mlir::scf::SCFDialect>)
  (import (chezscheme)
          (crest support foreign))
  (define %mlir::DialectRegistry::insert<mlir::scf::SCFDialect>
    (crest-foreign-procedure "mlir::DialectRegistry::insert<mlir::scf::SCFDialect>" (uptr) void)))
