#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/Region.h.
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Region) — Region helpers. Mirrors mlir/IR/Region.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Region)
  (export mlir::Region::push_back<Block>
          mlir::Region::front)
  (import (rnrs) (mlir IR Region ffi))

  ;; @brief mlir::Region::push_back<Block> — thin wrapper over %mlir::Region::push_back<Block>.
  ;;        Appends a new Block to a region with typed arguments.
  ;; @param region     Region* uptr — the target region
  ;; @param arg-types  Scheme list of Type* uptrs — types for the new block's arguments
  ;; @return           Block* uptr of the newly appended block; 0 if region is null
  ;; @see              mlir/IR/Region.h  Region::push_back
  ;; @note             Delegates to %mlir::Region::push_back<Block> in (mlir IR Region ffi);
  ;;                   C++ implementation in lib/Bindings/IR/Region.cpp
  (define mlir::Region::push_back<Block> %mlir::Region::push_back<Block>)

  ;; @brief mlir::Region::front — thin wrapper over %mlir::Region::front.
  ;;        Returns the first Block of a region.
  ;; @param region  Region* uptr — the target region
  ;; @return        Block* uptr; 0 if region is null or empty
  ;; @see           mlir/IR/Region.h  Region::front()
  ;; @note          Delegates to %mlir::Region::front in (mlir IR Region ffi);
  ;;                C++ implementation in lib/Bindings/IR/Region.cpp
  (define mlir::Region::front %mlir::Region::front)

  ) ;; end library (mlir IR Region)
