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
    %mlir::Region::push_back
    %mlir::Region::getParentOp
    mlir::Region::push_back<Block>
    mlir::Region::front)
  (import (rnrs)
          (mlir IR Region ffi)
          (only (mlir IR Block ffi) %mlir::Block::new %mlir::Block::addArgument)
          (only (mlir IR Operation) mlir::Operation::getLoc))


  (define mlir::Region::front %mlir::Region::front)

  ;; @brief mlir::Region::push_back<Block> — append a new block with typed arguments.
  ;; @param region    Region* uptr
  ;; @param arg-types Scheme list of Type* uptrs
  ;; @return          Block* uptr of the new block
  (define (mlir::Region::push_back<Block> region arg-types)
    (let* ([block (%mlir::Block::new)]
           [loc   (mlir::Operation::getLoc (%mlir::Region::getParentOp region))])
      (%mlir::Region::push_back region block)
      (for-each (lambda (t) (%mlir::Block::addArgument block t loc)) arg-types)
      block))

  ) ;; end library (mlir IR Region)
