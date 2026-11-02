#!r6rs
;; Ch6-specific: toy.print lowering to LLVM (PrintOpLowering).
(library (toy ch6 lower-to-llvm-ffi)
  (export %mlir::toy::ch6::populatePrintOpLoweringPatterns)
  (import (chezscheme))
  (define %mlir::toy::ch6::populatePrintOpLoweringPatterns
    (foreign-procedure "mlir::toy::ch6::populatePrintOpLoweringPatterns" (uptr uptr) void)))
