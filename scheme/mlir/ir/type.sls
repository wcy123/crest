#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir type) — mlir::Type base class bindings.
;;
;; Mirrors mlir/IR/Types.h.
;; Imports raw C bindings from (mlir ir type ffi) and re-exports clean names.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir type)
  (export type-get-context)
  (import (rnrs) (mlir ir type ffi))

  (define type-get-context %type-get-context)

) ;; end library (mlir ir type)
