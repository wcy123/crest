#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir core value) — compatibility shim over (mlir ir value).
;;
;; Re-exports (mlir ir value) under the legacy mlir-value-* names.
;; New code should import (mlir ir value) directly.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir core value)
  (export
    mlir-value-get-defining-op
    mlir-value-get-type
    mlir-value-is-block-argument?
    mlir-value-get-result-number
    mlir-value-num-uses
    ;; Re-exported from (mlir support array-ref).
    array-ref-size
    array-ref-at
    make-array-ref
    array-ref-destroy
    with-array-ref
    :uptr)

  (import (rnrs)
          (rename (mlir ir value)
            (get-defining-op   mlir-value-get-defining-op)
            (get-type          mlir-value-get-type)
            (block-argument?   mlir-value-is-block-argument?)
            (get-result-number mlir-value-get-result-number)
            (num-uses          mlir-value-num-uses))
          (mlir support array-ref))

) ;; end library (mlir core value)
