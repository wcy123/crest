#!r6rs
;; Mirrors mlir/Dialect/SCF/IR/SCFDialect.h
(library (mlir Dialect SCF IR SCFDialect)
  (export mlir::scf::SCFDialect)
  (import (rnrs) (mlir Dialect SCF IR SCFDialect ffi))
  (define mlir::scf::SCFDialect
    %mlir::scf::SCFDialect))
