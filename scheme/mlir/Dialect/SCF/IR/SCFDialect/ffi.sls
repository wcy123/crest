#!r6rs
;; Mirrors mlir/Dialect/SCF/IR/SCFDialect.h
(library (mlir Dialect SCF IR SCFDialect ffi)
  (export %mlir::scf::SCFDialect)
  (import (chezscheme))
  (define %mlir::scf::SCFDialect
    (foreign-procedure "mlir::scf::SCFDialect" (uptr) void)))
