#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;; Mirrors lib/Bindings/Support/Logging.h (CREST-specific, no MLIR counterpart).
;;===----------------------------------------------------------------------===;;
;;
;; (crest support logging ffi) — Raw FFI bindings for the MLIR logging system.
;;
;; Low-level %-prefixed procedures bound directly to C symbols.
;; Prefer importing (crest support logging) for the clean public API.
;;
;; CREST-specific (no direct MLIR header); mirrors lib/Bindings/Support/Logging.h.
;;
;;===----------------------------------------------------------------------===;;

(library (crest support logging ffi)
  (export
    %crest::logging::trace
    %crest::logging::debug
    %crest::logging::info
    %crest::logging::warning
    %crest::logging::error
    %crest::logging::fatal)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief Emit a TRACE-level log message (most verbose; off by default).
  ;; @param msg  string — message to emit
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define %crest::logging::trace   (foreign-procedure "crest::logging::trace"   (string) void))

  ;; @brief Emit a DEBUG-level log message (verbose developer information).
  ;; @param msg  string — message to emit
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define %crest::logging::debug   (foreign-procedure "crest::logging::debug"   (string) void))

  ;; @brief Emit an INFO-level log message (normal operational events).
  ;; @param msg  string — message to emit
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define %crest::logging::info    (foreign-procedure "crest::logging::info"    (string) void))

  ;; @brief Emit a WARNING-level log message (unexpected but recoverable condition).
  ;; @param msg  string — message to emit
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define %crest::logging::warning (foreign-procedure "crest::logging::warning" (string) void))

  ;; @brief Emit an ERROR-level log message (non-fatal error).
  ;; @param msg  string — message to emit
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define %crest::logging::error   (foreign-procedure "crest::logging::error"   (string) void))

  ;; @brief Emit a FATAL-level log message (unrecoverable; may abort the process).
  ;; @param msg  string — message to emit
  ;; @return     void
  ;; @note       Log level controlled by ChezSchemeInterpreter::setLogLevel
  ;; @note       Defined in lib/Bindings/Support/Logging.cpp
  (define %crest::logging::fatal   (foreign-procedure "crest::logging::fatal"   (string) void))

  ) ;; end library (crest support logging ffi)
