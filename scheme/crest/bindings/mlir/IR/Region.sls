#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Region) — Region lifecycle bindings.
;;
;; Mirrors mlir/IR/Region.h
;; Block construction bindings (mlir::Block::new, mlir::Block::addArgument)
;; live in (mlir IR Block) — mirrors mlir/IR/Block.h per Rule 1.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Region)
  (export
    mlir::Region::getParentOp
    mlir::Region::push_back<Block>
    mlir::Region::front)
  (import (rnrs)
          (mlir IR Region ffi)
          (only (mlir IR Block) mlir::Block::addArgument)
          (only (mlir IR Operation) mlir::Operation::getLoc)
          (only (mlir IR Location) mlir::UnknownLoc::get))


  ;; @brief mlir::Region::front — return the first Block in the region, or 0 if empty.
  ;; @param region  Region* uptr
  ;; @return        mlir::Block* uptr; 0 if the region has no blocks
  ;; @see           mlir/IR/Region.h
  (define mlir::Region::front %mlir::Region::front)

  ;; @brief mlir::Region::getParentOp — return the Operation that owns this region.
  ;; @param region  Region* uptr
  ;; @return        mlir::Operation* uptr
  ;; @see           mlir/IR/Region.h
  (define mlir::Region::getParentOp %mlir::Region::getParentOp)

  ;; @brief mlir::Region::push_back<Block> — append a new block with typed arguments.
  ;; @param region    Region* uptr
  ;; @param arg-types Scheme list of Type* uptrs
  ;; @return          Block* uptr of the new block
  (define (mlir::Region::push_back<Block> region arg-types)
    (let* ([block    (%mlir::Block::new)]
           [parent-op (%mlir::Region::getParentOp region)]
           ;; Parent op may be null when filling a region before %%crest:create-op!
           ;; (OperationState owns the region but the op doesn't exist yet).
           [loc     (if (zero? parent-op)
                        (mlir::UnknownLoc::get)
                        (mlir::Operation::getLoc parent-op))])
      (%mlir::Region::push_back region block)
      (for-each (lambda (t) (mlir::Block::addArgument block t loc)) arg-types)
      block))

  ) ;; end library (mlir IR Region)
