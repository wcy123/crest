#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/Value.h.
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir value ffi) — raw foreign-procedure bindings for mlir/IR/Value.h.
;;
;; All names have a % prefix to signal "raw C binding".
;; Import (mlir ir value) for the clean user-visible API.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir value ffi)
  (export
    %mlir::Value::getDefiningOp
    %mlir::isa<BlockArgument>?
    %mlir::Value::getUses
    %mlir::Value::getType
    %mlir::OpResult::getResultNumber)

  (import (rnrs)
          (only (chezscheme) foreign-procedure))

  ;; @brief mlir::Value::getDefiningOp() — return the operation that defines this value.
  ;; @param value  Value opaque pointer uptr
  ;; @return       Operation* opaque pointer uptr, or 0 if value is a block argument or null
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/Value.cpp
  (define %mlir::Value::getDefiningOp
    (foreign-procedure "mlir::Value::getDefiningOp" (uptr) uptr))

  ;; @brief mlir::isa<BlockArgument>(val) — check if value is a block argument.
  ;; @param value  Value opaque pointer uptr
  ;; @return       1 if BlockArgument, 0 otherwise
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/Value.cpp
  (define %mlir::isa<BlockArgument>?
    (foreign-procedure "mlir::isa<BlockArgument>" (uptr) int))

  ;; @brief mlir::Value::use_begin/use_end — count the number of uses of this value.
  ;; @param value  Value opaque pointer uptr
  ;; @return       Number of uses as uptr; 0 if value is null
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/Value.cpp
  (define %mlir::Value::getUses
    (foreign-procedure "mlir::Value::getUses" (uptr) uptr))

  ;; @brief mlir::Value::getType() — return the type of this value.
  ;; @param value  Value opaque pointer uptr
  ;; @return       Type opaque pointer uptr, or 0 if value is null
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/Value.cpp
  (define %mlir::Value::getType
    (foreign-procedure "mlir::Value::getType" (uptr) uptr))

  ;; @brief mlir::OpResult::getResultNumber — return the result index within the defining op.
  ;; @param value  Opaque Value* (mlir::OpResult) as uptr
  ;; @return       0-based result index as uptr; 0 if value is null or not an OpResult
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/OpResult.cpp; also registered as
  ;;               mlir_ir_value_get_result_number (C symbol alias)
  (define %mlir::OpResult::getResultNumber
    (foreign-procedure "mlir::OpResult::getResultNumber" (uptr) uptr))

) ;; end library (mlir ir value ffi)
