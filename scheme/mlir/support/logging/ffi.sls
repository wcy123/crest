#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support logging ffi) — Raw FFI bindings for the MLIR logging system.
;;
;; Low-level %-prefixed procedures bound directly to C symbols.
;; Prefer importing (mlir support logging) for the clean public API.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support logging ffi)
  (export
    %logging-trace
    %logging-debug
    %logging-info
    %logging-warning
    %logging-error
    %logging-fatal)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %logging-trace   (foreign-procedure "mlir_support_logging_trace"   (string) void))
  (define %logging-debug   (foreign-procedure "mlir_support_logging_debug"   (string) void))
  (define %logging-info    (foreign-procedure "mlir_support_logging_info"    (string) void))
  (define %logging-warning (foreign-procedure "mlir_support_logging_warning" (string) void))
  (define %logging-error   (foreign-procedure "mlir_support_logging_error"   (string) void))
  (define %logging-fatal   (foreign-procedure "mlir_support_logging_fatal"   (string) void))

) ;; end library (mlir support logging ffi)
