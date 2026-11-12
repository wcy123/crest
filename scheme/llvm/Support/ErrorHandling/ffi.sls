#!r6rs
;; Mirrors llvm/Support/ErrorHandling.h
(library (llvm Support ErrorHandling ffi)
  (export %llvm::report_fatal_error)
  (import (chezscheme)
          (mlir support foreign))

  ;; (string text) -> void; it does not return
  (define %llvm::report_fatal_error
    (crest-foreign-procedure "llvm::report_fatal_error" (string) void))

  ) ;; end library (llvm Support ErrorHandling ffi)
