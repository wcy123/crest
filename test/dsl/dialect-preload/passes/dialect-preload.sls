#!r6rs
;; Tests that dialects= pre-loads the specified dialects before Scheme runs.
;; The pass prints the name of the first func.func operation it finds,
;; proving the func dialect was properly loaded and recognized.
(library (passes dialect-preload)
  (export run-pass)
  (import (chezscheme)
          (mlir IR Operation)
          (mlir IR Region)
          (mlir IR Block))

  (define (run-pass module)
    (let* ([region (mlir::Operation::getRegion module 0)]
           [block  (mlir::Region::front region)]
           [op     (mlir::Block::front block)])
      (display "first-op: ")
      (display (mlir::Operation::getName op))
      (newline))
    module))
