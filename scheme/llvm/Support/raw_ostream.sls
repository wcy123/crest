#!r6rs
;; Mirrors llvm/Support/raw_ostream.h
;;
;; The stream is one that C++ gave for the length of a callback (mlir::AsmPrinter::getStream).
(library (llvm Support raw_ostream)
  (export llvm::raw_ostream::write)
  (import (rnrs)
          (llvm Support raw_ostream ffi))

  (define llvm::raw_ostream::write %llvm::raw_ostream::write)

  ) ;; end library (llvm Support raw_ostream)
