#!r6rs
;; Mirrors llvm/Support/ErrorHandling.h
;;
;; The process ends with the text; nothing after the call runs.
(library (llvm Support ErrorHandling)
  (export llvm::report_fatal_error)
  (import (rnrs)
          (llvm Support ErrorHandling ffi))

  (define llvm::report_fatal_error %llvm::report_fatal_error)

  ) ;; end library (llvm Support ErrorHandling)
