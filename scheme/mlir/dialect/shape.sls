#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialect shape) — Shape dialect type factories.
;;
;; Mirrors mlir/Dialect/Shape/IR/Shape.h.
;; Imports raw C bindings from (mlir dialect shape ffi) and re-exports
;; under clean names. Add Scheme-level helpers here as needed.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialect shape)
  (export shape-type-get size-type-get witness-type-get)
  (import (rnrs) (mlir dialect shape ffi))

  (define shape-type-get   %shape-type-get)
  (define size-type-get    %size-type-get)
  (define witness-type-get %witness-type-get)

) ;; end library (mlir dialect shape)
