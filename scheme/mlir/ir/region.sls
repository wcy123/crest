#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir region) — Region helpers. Mirrors mlir/IR/Region.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir region)
  (export region-append-new-block
          region-get-first-block)
  (import (rnrs) (mlir ir region ffi))

  ;; @brief region-append-new-block — thin wrapper over %region-append-new-block.
  ;;        Appends a new Block to a region with typed arguments.
  ;; @param region     Region* uptr — the target region
  ;; @param arg-types  Scheme list of Type* uptrs — types for the new block's arguments
  ;; @return           Block* uptr of the newly appended block; 0 if region is null
  ;; @see              mlir/IR/Region.h  Region::push_back
  ;; @note             Delegates to %region-append-new-block in (mlir ir region ffi);
  ;;                   C++ implementation in lib/Bindings/IR/Region.cpp
  (define region-append-new-block %region-append-new-block)

  ;; @brief region-get-first-block — thin wrapper over %region-get-first-block.
  ;;        Returns the first Block of a region.
  ;; @param region  Region* uptr — the target region
  ;; @return        Block* uptr; 0 if region is null or empty
  ;; @see           mlir/IR/Region.h  Region::front()
  ;; @note          Delegates to %region-get-first-block in (mlir ir region ffi);
  ;;                C++ implementation in lib/Bindings/IR/Region.cpp
  (define region-get-first-block %region-get-first-block)

) ;; end library (mlir ir region)
