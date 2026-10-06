#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/Block.h.
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Block) — Block helpers. Mirrors mlir/IR/Block.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Block)
  (export mlir::Block::getArgument
          mlir::Block::getNumArguments)
  (import (rnrs) (mlir IR Block ffi))

  ;; @brief mlir::Block::getArgument — return the idx-th block argument.
  ;; @param block  Block* uptr
  ;; @param idx    0-based argument index (int)
  ;; @return       Value opaque pointer uptr; 0 if null or index out of range
  ;; @see          mlir/IR/Block.h
  (define mlir::Block::getArgument %mlir::Block::getArgument)

  ;; @brief mlir::Block::getNumArguments — return the number of block arguments.
  ;; @param block  Block* uptr (must be non-null)
  ;; @return       Argument count (uptr)
  ;; @see          mlir/IR/Block.h
  (define mlir::Block::getNumArguments %mlir::Block::getNumArguments)

) ;; end library (mlir IR Block)
