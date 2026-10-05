#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir value) — mlir/IR/Value.h user-visible API.
;;
;; Function names follow the C++ method names without the class prefix.
;; Users may add a prefix (mlir-ir-value-, value-, etc.) as desired.
;;
;; Raw C bindings live in (mlir ir value ffi) with % prefix.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir value)
  (export
    get-defining-op
    block-argument?
    num-uses
    get-type)

  (import (rnrs)
          (mlir ir value ffi))

  ;; @brief mlir::Value::getDefiningOp() — return the operation that defines this value.
  ;; @param value  Value opaque pointer uptr
  ;; @return       Operation* opaque pointer uptr, or 0 if value is a block argument or null
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/Value.cpp
  (define get-defining-op %get-defining-op)

  ;; @brief mlir::isa<BlockArgument>(val) — predicate: is the value a block argument?
  ;; @param value  Value opaque pointer uptr
  ;; @return       #t if BlockArgument, #f otherwise
  ;; @see          mlir/IR/Value.h
  ;; @note         Wraps %block-argument?; returns boolean instead of 1/0
  (define (block-argument? val)
    (= 1 (%block-argument? val)))

  ;; @brief mlir::Value::use_begin/use_end — count the number of uses of this value.
  ;; @param value  Value opaque pointer uptr
  ;; @return       Number of uses as uptr; 0 if value is null
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/Value.cpp
  (define num-uses %num-uses)

  ;; @brief mlir::Value::getType() — return the type of this value.
  ;; @param value  Value opaque pointer uptr
  ;; @return       Type opaque pointer uptr, or 0 if value is null
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/Value.cpp
  (define get-type %get-type)

) ;; end library (mlir ir value)
