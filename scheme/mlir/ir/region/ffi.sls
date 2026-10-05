#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir region ffi) — raw C bindings for mlir/IR/Region.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir region ffi)
  (export %region-append-new-block
          %region-get-first-block)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir_ir_region_append_new_block — append a new Block to a region
  ;;        with typed arguments.
  ;; @param region     Region* uptr — the target region
  ;; @param arg-types  Scheme list of Type* uptrs — types for the new block's arguments
  ;; @return           Block* uptr of the newly appended block; 0 if region is null
  ;; @see              mlir/IR/Region.h  Region::push_back
  ;; @note             Defined in lib/Bindings/IR/Region.cpp ::mlir_ir_region_append_new_block
  (define %region-append-new-block
    (foreign-procedure "mlir_ir_region_append_new_block" (uptr scheme-object) uptr))

  ;; @brief mlir_ir_region_get_first_block — return the first Block of a region.
  ;; @param region  Region* uptr — the target region
  ;; @return        Block* uptr; 0 if region is null or empty
  ;; @see           mlir/IR/Region.h  Region::front()
  ;; @note          Defined in lib/Bindings/IR/Region.cpp ::mlir_ir_region_get_first_block
  (define %region-get-first-block
    (foreign-procedure "mlir_ir_region_get_first_block" (uptr) uptr))

) ;; end library (mlir ir region ffi)
