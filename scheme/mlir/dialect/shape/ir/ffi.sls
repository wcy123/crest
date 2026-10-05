#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialect shape ir ffi) — raw C bindings for mlir/Dialect/Shape/IR/Shape.h.
;;
;; % prefix = raw C binding. Prefer (mlir dialect shape ir) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialect shape ir ffi)
  (export %shape-type-get %size-type-get %witness-type-get)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %shape-type-get
    (foreign-procedure "mlir_dialect_shape_ir_shape_type_get" (uptr) uptr))

  (define %size-type-get
    (foreign-procedure "mlir_dialect_shape_ir_size_type_get" (uptr) uptr))

  (define %witness-type-get
    (foreign-procedure "mlir_dialect_shape_ir_witness_type_get" (uptr) uptr))

) ;; end library (mlir dialect shape ir ffi)
