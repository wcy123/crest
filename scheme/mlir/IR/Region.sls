#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Region) — Region and Block lifecycle bindings.
;;
;; Mirrors mlir/IR/Region.h
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Region)
  (export
    %mlir::Block::new
    %mlir::Region::push_back
    %mlir::Block::addArgument
    %mlir::Region::getParentOp
    mlir::Region::push_back<Block>
    mlir::Region::front)
  (import (rnrs)
          (mlir IR Region ffi)
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
