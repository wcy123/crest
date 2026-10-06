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
;; (mlir IR Block ffi) — raw C bindings for mlir/IR/Block.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Block ffi)
  (export %mlir::Block::getArgument
          %mlir::Block::getNumArguments)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::Block::getArgument — return the idx-th block argument.
  ;; @param block  Block* uptr
  ;; @param idx    0-based argument index (int)
  ;; @return       Value opaque pointer uptr; 0 if null or index out of range
  ;; @see          mlir/IR/Block.h
  ;; @note         Defined in lib/Bindings/IR/Block.cpp
  (define %mlir::Block::getArgument
    (foreign-procedure "mlir::Block::getArgument" (uptr int) uptr))

  ;; @brief mlir::Block::getNumArguments — return the number of block arguments.
  ;; @param block  Block* uptr (must be non-null)
  ;; @return       Argument count (uptr)
  ;; @see          mlir/IR/Block.h
  ;; @note         Defined in lib/Bindings/IR/Block.cpp
  (define %mlir::Block::getNumArguments
    (foreign-procedure "mlir::Block::getNumArguments" (uptr) uptr))

) ;; end library (mlir IR Block ffi)
