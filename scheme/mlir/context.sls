#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir context) — ambient MLIRContext dynamic parameter.
;;
;; The MLIRContext is the root owner of all MLIR types, attributes, and
;; operations.  This module provides a dynamic parameter so that the
;; context does not need to be threaded explicitly through every call.
;;
;; Usage:
;;   (with-mlir-context ctx
;;     (mlir-get-index-type)   ; no explicit ctx needed
;;     (mlir-get-i64-type))
;;
;; Pattern callbacks install it automatically via with-rewrite-builder.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir context)
  (export
    current-mlir-context
    with-mlir-context)
  (import (rnrs)
          (only (chezscheme) make-parameter parameterize))

  ;; Current MLIRContext* uptr (or #f when unset).
  (define current-mlir-context (make-parameter #f))

  ;; RAII macro: install ctx as current-mlir-context for the duration of body.
  (define-syntax with-mlir-context
    (syntax-rules ()
      [(_ ctx body ...)
       (parameterize ([current-mlir-context ctx]) body ...)]))

) ;; end library (mlir context)
