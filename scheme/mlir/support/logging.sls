#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support logging) — Scheme-level logging bound to the MLIR log system.
;;
;; Mirrors lib/Bindings/Support/Logging.cpp.
;; All functions take a single string message and return void.
;; The log level is controlled via ChezSchemeInterpreter::setLogLevel;
;; higher-severity levels are always emitted.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support logging)
  (export
    mlir-log-trace
    mlir-log-debug
    mlir-log-info
    mlir-log-warning
    mlir-log-error
    mlir-log-fatal)
  (import (rnrs) (mlir support logging ffi))

  ;; Emit a TRACE-level log message (most verbose; off by default).
  ;; msg: message string
  (define mlir-log-trace   %logging-trace)

  ;; Emit a DEBUG-level log message (verbose developer information).
  ;; msg: message string
  (define mlir-log-debug   %logging-debug)

  ;; Emit an INFO-level log message (normal operational events).
  ;; msg: message string
  (define mlir-log-info    %logging-info)

  ;; Emit a WARNING-level log message (unexpected but recoverable condition).
  ;; msg: message string
  (define mlir-log-warning %logging-warning)

  ;; Emit an ERROR-level log message (non-fatal error).
  ;; msg: message string
  (define mlir-log-error   %logging-error)

  ;; Emit a FATAL-level log message (unrecoverable; may abort the process).
  ;; msg: message string
  (define mlir-log-fatal   %logging-fatal)

) ;; end library (mlir support logging)
