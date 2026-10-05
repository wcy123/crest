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
;; Mirrors mlir/IR/Value.h.
;;
;; Function names follow the C++ method names without the class prefix.
;; Users may add a prefix (mlir-ir-value-, value-, etc.) as desired.
;;
;; Raw C bindings live in (mlir ir value ffi) with % prefix.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir value)
  (export
    mlir::Value::getDefiningOp
    mlir::isa<BlockArgument>?
    mlir::Value::getUses
    mlir::Value::getType
    mlir::OpResult::getResultNumber)

  (import (rnrs)
          (mlir ir value ffi))

  ;; @brief mlir::Value::getDefiningOp() — return the operation that defines this value.
  ;; @param value  Value opaque pointer uptr
  ;; @return       Operation* opaque pointer uptr, or 0 if value is a block argument or null
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/Value.cpp
  (define mlir::Value::getDefiningOp %mlir::Value::getDefiningOp)

  ;; @brief mlir::isa<BlockArgument>(val) — predicate: is the value a block argument?
  ;; @param value  Value opaque pointer uptr
  ;; @return       #t if BlockArgument, #f otherwise
  ;; @see          mlir/IR/Value.h
  ;; @note         Wraps %mlir::isa<BlockArgument>?; returns boolean instead of 1/0
  (define (mlir::isa<BlockArgument>? val)
    (= 1 (%mlir::isa<BlockArgument>? val)))

  ;; @brief mlir::Value::use_begin/use_end — count the number of uses of this value.
  ;; @param value  Value opaque pointer uptr
  ;; @return       Number of uses as uptr; 0 if value is null
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/Value.cpp
  (define mlir::Value::getUses %mlir::Value::getUses)

  ;; @brief mlir::Value::getType() — return the type of this value.
  ;; @param value  Value opaque pointer uptr
  ;; @return       Type opaque pointer uptr, or 0 if value is null
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/Value.cpp
  (define mlir::Value::getType %mlir::Value::getType)

  ;; @brief mlir::OpResult::getResultNumber — return the result index within the defining op.
  ;; @param value  Opaque Value* (mlir::OpResult) as uptr
  ;; @return       0-based result index; 0 if value is null or not an OpResult
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/OpResult.cpp
  (define mlir::OpResult::getResultNumber %mlir::OpResult::getResultNumber)

) ;; end library (mlir ir value)
