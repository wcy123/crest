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
  (export %block-get-argument)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir_ir_block_get_argument — walk up from an Operation* to the
  ;;        nearest enclosing func.func and return its index-th block argument
  ;;        as an opaque Value pointer.
  ;; @param op     Operation* uptr — any op nested inside a func.func
  ;; @param index  0-based argument index (int)
  ;; @return       Value opaque pointer uptr; 0 if op is null, no enclosing
  ;;               func.func is found, or index is out of range
  ;; @see          mlir/IR/Block.h, mlir/Dialect/Func/IR/FuncOps.h
  ;; @note         Defined in lib/Bindings/IR/Block.cpp ::mlir_ir_block_get_argument
  (define %block-get-argument
    (foreign-procedure "mlir_ir_block_get_argument" (uptr int) uptr))

) ;; end library (mlir ir block ffi)
