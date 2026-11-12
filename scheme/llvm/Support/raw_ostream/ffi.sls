#!r6rs
;; Mirrors llvm/Support/raw_ostream.h
(library (llvm Support raw_ostream ffi)
  (export %llvm::raw_ostream::write)
  (import (chezscheme)
          (mlir support foreign))

  ;; (uptr stream) (string text) -> void
  (define %llvm::raw_ostream::write
    (crest-foreign-procedure "llvm::raw_ostream::write" (uptr string) void))

  ) ;; end library (llvm Support raw_ostream ffi)
