#!r6rs
;; Mirrors llvm/Support/raw_ostream.h
(library (llvm Support raw_ostream ffi)
  (export %llvm::raw_ostream::write)
  (import (chezscheme))

  ;; (uptr stream) (string text) -> void
  (define %llvm::raw_ostream::write
    (foreign-procedure "llvm::raw_ostream::write" (uptr string) void))

  ) ;; end library (llvm Support raw_ostream ffi)
