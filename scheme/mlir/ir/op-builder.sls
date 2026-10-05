#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir op-builder) — OpBuilder user-visible API.
;;
;; Mirrors mlir/IR/Builders.h OpBuilder.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir op-builder)
  (export
    op-builder-create
    op-builder-create-with-regions
    op-builder-at-block-end
    op-builder-destroy)
  (import (rnrs) (mlir ir op-builder ffi))

  (define op-builder-create              %op-builder-create)
  (define op-builder-create-with-regions %op-builder-create-with-regions)
  (define op-builder-at-block-end        %op-builder-at-block-end)
  (define op-builder-destroy             %op-builder-destroy)

) ;; end library (mlir ir op-builder)
