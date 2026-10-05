#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir op-builder ffi) — raw C bindings for mlir/IR/Builders.h OpBuilder.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir op-builder ffi)
  (export
    %op-builder-create
    %op-builder-create-with-regions
    %op-builder-at-block-end
    %op-builder-destroy)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %op-builder-create
    (foreign-procedure "mlir_ir_op_builder_create"
                       (uptr uptr string scheme-object scheme-object) uptr))

  (define %op-builder-create-with-regions
    (foreign-procedure "mlir_ir_op_builder_create_with_regions"
                       (uptr uptr string scheme-object scheme-object int) uptr))

  (define %op-builder-at-block-end
    (foreign-procedure "mlir_ir_op_builder_at_block_end" (uptr) uptr))

  (define %op-builder-destroy
    (foreign-procedure "mlir_ir_op_builder_destroy" (uptr) void))

) ;; end library (mlir ir op-builder ffi)
