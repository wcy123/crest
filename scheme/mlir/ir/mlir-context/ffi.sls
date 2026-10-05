#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir mlir-context ffi) — Raw C bindings for mlir::MLIRContext methods.
;;
;; Mirrors mlir/IR/MLIRContext.h.
;; All procedures are prefixed with % to indicate raw/internal FFI.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir mlir-context ffi)
  (export
    %mlir-context-allow-unregistered-dialects
    %mlir-context-allows-unregistered-dialects
    %mlir-context-enable-multithreading
    %mlir-context-disable-multithreading
    %mlir-context-is-multithreading-enabled
    %mlir-context-get-or-load-dialect
    %mlir-context-load-all-available-dialects
    %mlir-context-print-op-on-diagnostic
    %mlir-context-should-print-op-on-diagnostic
    %mlir-context-print-stack-trace-on-diagnostic)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %mlir-context-allow-unregistered-dialects
    (foreign-procedure "mlir_ir_mlir_context_allow_unregistered_dialects" (uptr int) void))
  (define %mlir-context-allows-unregistered-dialects
    (foreign-procedure "mlir_ir_mlir_context_allows_unregistered_dialects" (uptr) int))
  (define %mlir-context-enable-multithreading
    (foreign-procedure "mlir_ir_mlir_context_enable_multithreading" (uptr int) void))
  (define %mlir-context-disable-multithreading
    (foreign-procedure "mlir_ir_mlir_context_disable_multithreading" (uptr int) void))
  (define %mlir-context-is-multithreading-enabled
    (foreign-procedure "mlir_ir_mlir_context_is_multithreading_enabled" (uptr) int))
  (define %mlir-context-get-or-load-dialect
    (foreign-procedure "mlir_ir_mlir_context_get_or_load_dialect" (uptr string) uptr))
  (define %mlir-context-load-all-available-dialects
    (foreign-procedure "mlir_ir_mlir_context_load_all_available_dialects" (uptr) void))
  (define %mlir-context-print-op-on-diagnostic
    (foreign-procedure "mlir_ir_mlir_context_print_op_on_diagnostic" (uptr int) void))
  (define %mlir-context-should-print-op-on-diagnostic
    (foreign-procedure "mlir_ir_mlir_context_should_print_op_on_diagnostic" (uptr) int))
  (define %mlir-context-print-stack-trace-on-diagnostic
    (foreign-procedure "mlir_ir_mlir_context_print_stack_trace_on_diagnostic" (uptr int) void))
) ;; end library (mlir ir mlir-context ffi)
