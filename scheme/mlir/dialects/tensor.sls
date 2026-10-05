#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects tensor) — Generic tensor type operations.
;;
;; Mirrors mlir/Dialect/Tensor/IR/Tensor.h for type-level operations.
;; These are dialect-agnostic: they operate on RankedTensorType and
;; accept any MLIR attribute as an encoding.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialects tensor)
  (export mlir-ranked-tensor-type-with-encoding)

  (import (rnrs) (mlir dialects tensor ffi))

  (define mlir-ranked-tensor-type-with-encoding
    %ranked-tensor-type-with-encoding)

) ;; end library (mlir dialects tensor)
