#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir rewriter-base ffi) — raw C bindings for mlir/IR/PatternMatch.h RewriterBase.
;;
;; % prefix = raw C binding. Prefer (mlir ir rewriter-base) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir rewriter-base ffi)
  (export
    %rewriter-base-create
    %rewriter-base-create-with-regions
    %rewriter-base-set-insertion-point-before
    %rewriter-base-set-insertion-point-to-end
    %rewriter-base-create-block
    %rewriter-base-replace-op
    %rewriter-base-erase-op
    %rewriter-base-clone-with-types)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %rewriter-base-create
    (foreign-procedure "mlir_ir_rewriter_base_create"
                       (uptr uptr string scheme-object scheme-object) uptr))

  (define %rewriter-base-create-with-regions
    (foreign-procedure "mlir_ir_rewriter_base_create_with_regions"
                       (uptr uptr string scheme-object scheme-object int) uptr))

  (define %rewriter-base-set-insertion-point-before
    (foreign-procedure "mlir_ir_rewriter_base_set_insertion_point_before"
                       (uptr uptr) void))

  (define %rewriter-base-set-insertion-point-to-end
    (foreign-procedure "mlir_ir_rewriter_base_set_insertion_point_to_end"
                       (uptr uptr) void))

  (define %rewriter-base-create-block
    (foreign-procedure "mlir_ir_rewriter_base_create_block"
                       (uptr uptr scheme-object) uptr))

  (define %rewriter-base-replace-op
    (foreign-procedure "mlir_ir_rewriter_base_replace_op"
                       (uptr uptr uptr) int))

  (define %rewriter-base-erase-op
    (foreign-procedure "mlir_ir_rewriter_base_erase_op"
                       (uptr uptr) int))

  (define %rewriter-base-clone-with-types
    (foreign-procedure "mlir_ir_rewriter_base_clone_with_types"
                       (uptr uptr scheme-object scheme-object) uptr))

) ;; end library (mlir ir rewriter-base ffi)
