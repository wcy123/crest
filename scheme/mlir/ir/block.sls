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
  (export block-get-argument)
  (import (rnrs) (mlir ir block ffi))

  ;; @brief block-get-argument — thin wrapper over %block-get-argument.
  ;;        Walks up from op to the nearest enclosing func.func and returns
  ;;        its index-th block argument as an opaque Value pointer.
  ;; @param op     Operation* uptr — any op nested inside a func.func
  ;; @param index  0-based argument index (int)
  ;; @return       Value opaque pointer uptr; 0 if op is null, no enclosing
  ;;               func.func is found, or index is out of range
  ;; @see          mlir/IR/Block.h, mlir/Dialect/Func/IR/FuncOps.h
  ;; @note         Delegates to %block-get-argument in (mlir ir block ffi);
  ;;               C++ implementation in lib/Bindings/IR/Block.cpp
  (define block-get-argument %block-get-argument)

) ;; end library (mlir ir block)
