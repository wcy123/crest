#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir block) — Block helpers. Mirrors mlir/IR/Block.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir block)
  (export block-get-argument-by-index
          block-get-num-arguments)
  (import (rnrs) (mlir ir block ffi))

  ;; @brief mlir::Block::getArgument — return the idx-th block argument.
  ;; @param block  Block* uptr
  ;; @param idx    0-based argument index (int)
  ;; @return       Value opaque pointer uptr; 0 if null or index out of range
  ;; @see          mlir/IR/Block.h
  (define block-get-argument-by-index %block-get-argument-by-index)

  ;; @brief mlir::Block::getNumArguments — return the number of block arguments.
  ;; @param block  Block* uptr (must be non-null)
  ;; @return       Argument count (uptr)
  ;; @see          mlir/IR/Block.h
  (define block-get-num-arguments %block-get-num-arguments)

) ;; end library (mlir ir block)
