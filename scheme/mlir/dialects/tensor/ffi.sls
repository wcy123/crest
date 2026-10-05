#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects tensor ffi) — raw C bindings for tensor dialect type ops.
;;
;; % prefix = raw C binding. Prefer (mlir dialects tensor) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialects tensor ffi)
  (export %ranked-tensor-type-with-encoding)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %ranked-tensor-type-with-encoding
    (foreign-procedure "mlir_tensor_type_with_encoding" (uptr uptr) uptr))

) ;; end library (mlir dialects tensor ffi)
