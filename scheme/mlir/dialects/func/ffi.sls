#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects func ffi) — raw C bindings for func dialect helpers.
;;
;; % prefix = raw C binding. Prefer (mlir dialects func) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialects func ffi)
  (export %populate-func-type-conversion-pattern)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %populate-func-type-conversion-pattern
    (foreign-procedure "mlir_populate_func_type_conversion_pattern" (uptr uptr) void))

) ;; end library (mlir dialects func ffi)
