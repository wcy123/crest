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

  ;; @brief Emit a TRACE-level log message (most verbose; off by default).
  ;; @param msg  Message string
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define mlir-log-trace   %logging-trace)

  ;; @brief Emit a DEBUG-level log message via CREST's logging system.
  ;; @param msg  Message string
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define mlir-log-debug   %logging-debug)

  ;; @brief Emit an INFO-level log message (normal operational events).
  ;; @param msg  Message string
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define mlir-log-info    %logging-info)

  ;; @brief Emit a WARNING-level log message (unexpected but recoverable condition).
  ;; @param msg  Message string
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define mlir-log-warning %logging-warning)

  ;; @brief Emit an ERROR-level log message (non-fatal error).
  ;; @param msg  Message string
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define mlir-log-error   %logging-error)

  ;; @brief Emit a FATAL-level log message (unrecoverable; may abort the process).
  ;; @param msg  Message string
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define mlir-log-fatal   %logging-fatal)

) ;; end library (mlir support logging)
