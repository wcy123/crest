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
  (export block-get-argument-by-index)
  (import (rnrs) (mlir ir block ffi))

  ;; @brief block-get-argument-by-index — thin wrapper over %block-get-argument-by-index.
  ;;        Returns the idx-th argument of a Block directly by index.
  ;; @param block  Block* uptr — the block
  ;; @param idx    0-based argument index (int)
  ;; @return       Value opaque pointer uptr; 0 if block is null or index out of range
  ;; @see          mlir/IR/Block.h  Block::getArgument(unsigned)
  ;; @note         Delegates to %block-get-argument-by-index in (mlir ir block ffi);
  ;;               C++ implementation in lib/Bindings/IR/Block.cpp
  (define block-get-argument-by-index %block-get-argument-by-index)

) ;; end library (mlir ir block)
