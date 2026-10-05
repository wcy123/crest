#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir operation-state ffi) — Raw C bindings for mlir::OperationState.
;;
;; Mirrors mlir/IR/OperationSupport.h.
;; All procedures are prefixed with % to indicate raw/internal FFI.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir operation-state ffi)
  (export
    %operation-state-create
    %operation-state-add-operands          ;; canonical: mlir::OperationState::addOperands
    %operation-state-add-operand           ;; backward-compat alias
    %operation-state-add-types             ;; canonical: mlir::OperationState::addTypes
    %operation-state-add-result-type       ;; backward-compat alias
    %operation-state-add-region
    %operation-state-destroy)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::OperationState constructor — heap-allocate an OperationState for loc and op name.
  ;; @param loc-ptr   Location opaque ptr as uptr (from %mlir::Operation::getLoc)
  ;; @param name      Registered MLIR op name string (e.g. "arith.constant")
  ;; @return          OperationState* as uptr — caller must destroy with %operation-state-destroy
  ;; @see             mlir/IR/OperationSupport.h
  ;; @note            Defined in lib/Bindings/IR/OperationState.cpp
  (define %operation-state-create
    (foreign-procedure "mlir_ir_operation_state_create" (uptr string) uptr))

  ;; @brief mlir::OperationState::addOperands — add a single operand Value to the state.
  ;; @param state   OperationState* uptr
  ;; @param value   Value opaque ptr as uptr
  ;; @return        void
  ;; @see           mlir/IR/OperationSupport.h
  ;; @note          Defined in lib/Bindings/IR/OperationState.cpp
  (define %operation-state-add-operands
    (foreign-procedure "mlir_ir_operation_state_add_operands" (uptr uptr) void))

  ;; @brief Backward-compat alias for %operation-state-add-operands.
  (define %operation-state-add-operand %operation-state-add-operands)

  ;; @brief mlir::OperationState::addTypes — add a single result Type to the state.
  ;; @param state   OperationState* uptr
  ;; @param type    Type opaque ptr as uptr
  ;; @return        void
  ;; @see           mlir/IR/OperationSupport.h
  ;; @note          Defined in lib/Bindings/IR/OperationState.cpp
  (define %operation-state-add-types
    (foreign-procedure "mlir_ir_operation_state_add_types" (uptr uptr) void))

  ;; @brief Backward-compat alias for %operation-state-add-types.
  (define %operation-state-add-result-type %operation-state-add-types)

  ;; @brief mlir::OperationState::addRegion — add one empty region to the state.
  ;; @param state   OperationState* uptr
  ;; @return        void
  ;; @see           mlir/IR/OperationSupport.h
  ;; @note          Defined in lib/Bindings/IR/OperationState.cpp
  ;; @note          Required for ops that verify they have exactly N regions at creation time.
  (define %operation-state-add-region
    (foreign-procedure "mlir_ir_operation_state_add_region" (uptr) void))

  ;; @brief Destroy an OperationState created by %operation-state-create.
  ;; @param state   OperationState* uptr — no-op if 0
  ;; @return        void
  ;; @see           mlir/IR/OperationSupport.h
  ;; @note          Defined in lib/Bindings/IR/OperationState.cpp
  (define %operation-state-destroy
    (foreign-procedure "mlir_ir_operation_state_destroy" (uptr) void))

) ;; end library (mlir ir operation-state ffi)
