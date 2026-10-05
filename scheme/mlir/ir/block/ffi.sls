#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir block ffi) — raw C bindings for mlir/IR/Block.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir block ffi)
  (export %block-get-argument-by-index)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir_ir_block_get_argument_by_index — get the idx-th argument of a
  ;;        block directly by index (no func.func walk).
  ;; @param block  Block* uptr — the block
  ;; @param idx    0-based argument index (int)
  ;; @return       Value opaque pointer uptr; 0 if block is null or index out of range
  ;; @see          mlir/IR/Block.h  Block::getArgument(unsigned)
  ;; @note         Defined in lib/Bindings/IR/Block.cpp ::mlir_ir_block_get_argument_by_index
  (define %block-get-argument-by-index
    (foreign-procedure "mlir_ir_block_get_argument_by_index" (uptr int) uptr))

) ;; end library (mlir ir block ffi)
