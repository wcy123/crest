#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialect shape ffi) — raw C bindings for Shape dialect type factories.
;;
;; Direct foreign-procedure wrappers only. No logic, no helpers.
;; % prefix signals raw C binding — prefer (mlir dialect shape) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialect shape ffi)
  (export %shape-type-get %size-type-get %witness-type-get)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %shape-type-get
    (foreign-procedure "mlir_dialect_shape_shape_type_get" (uptr) uptr))

  (define %size-type-get
    (foreign-procedure "mlir_dialect_shape_size_type_get" (uptr) uptr))

  (define %witness-type-get
    (foreign-procedure "mlir_dialect_shape_witness_type_get" (uptr) uptr))

) ;; end library (mlir dialect shape ffi)
