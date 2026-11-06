#!r6rs
;; Mirrors mlir/Dialect/SCF/IR/SCFDialect.h
(library (mlir Dialect SCF IR SCFDialect)
  (export mlir::DialectRegistry::insert<mlir::scf::SCFDialect>)
  (import (rnrs) (mlir Dialect SCF IR SCFDialect ffi))
  (define mlir::DialectRegistry::insert<mlir::scf::SCFDialect>
    %mlir::DialectRegistry::insert<mlir::scf::SCFDialect>))
