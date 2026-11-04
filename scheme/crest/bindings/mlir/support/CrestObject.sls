#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;; Mirrors lib/Bindings/Support/CrestObject.h (CREST-specific, no MLIR counterpart).
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support CrestObject) — generic base for all CREST-managed foreign objects.
;;
;; Every CrestObject starts with an 8-byte deletor (function pointer) at offset 0.
;; It is both the destructor and the type tag.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support CrestObject)
  (export
    CrestObject::deletor    ; (obj) → uptr: read deletor address (type tag)
    CrestObject::delete     ; (obj) → void: call deletor, freeing the object
    with-CrestObject)       ; (syntax) RAII for any CrestObject

  (import (rnrs)
          (only (chezscheme) foreign-ref)
          (mlir support CrestObject ffi))

  ;; @brief CrestObject::deletor — read the deletor (type tag) from a CrestObject.
  ;; @param obj  uptr — pointer to any CrestObject
  ;; @return     uptr — address of the deletor function (unique per concrete type)
  (define (CrestObject::deletor obj)
    (foreign-ref 'uptr obj 0))

  ;; @brief CrestObject::delete — call the stored deletor, freeing the object.
  ;; @param obj  uptr — pointer to any CrestObject
  (define CrestObject::delete %CrestObject::delete)

  ;; @brief with-CrestObject — RAII for any CrestObject: binds NAME to the shell that INIT
  ;; creates, runs BODY, then frees the shell on exit (normal return, error, or escape).
  ;; @example
  ;;   (with-CrestObject state (mlir::OperationState::create loc "my.op")
  ;;     ...)
  (define-syntax with-CrestObject
    (syntax-rules ()
      [(_ name init body ...)
       (let ([name init])
         (dynamic-wind
             (lambda () #f)
             (lambda () body ...)
             (lambda () (CrestObject::delete name))))]))

  ) ;; end library (mlir support CrestObject)
