#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/Block.h.
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Block) — Block helpers. Mirrors mlir/IR/Block.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Block)
  (export mlir::Block::getArgument
          mlir::Block::getNumArguments
          mlir::Block::addArgument)
  (import (rnrs) (mlir IR Block ffi))

  ;; @brief mlir::Block::getArgument — return the idx-th block argument.
  ;; @param block  Block* uptr
  ;; @param idx    0-based argument index (exact integer)
  ;; @return       mlir::BlockArgument opaque pointer uptr (subclass of mlir::Value)
  ;; @error        raises error 'mlir::Block::getArgument if idx is out of range
  ;; @see          mlir/IR/Block.h
  (define (mlir::Block::getArgument block idx)
    (let ([n (mlir::Block::getNumArguments block)])
      (unless (and (>= idx 0) (< idx n))
        (error 'mlir::Block::getArgument "index out of range" idx n))
      (%mlir::Block::getArgument block idx)))

  ;; @brief mlir::Block::getNumArguments — return the number of block arguments.
  ;; @param block  Block* uptr (must be non-null)
  ;; @return       Argument count (uptr)
  ;; @see          mlir/IR/Block.h
  (define mlir::Block::getNumArguments %mlir::Block::getNumArguments)

  ;; @note %mlir::Block::new is intentionally NOT exported.
  ;;       Blocks must be pushed into a Region immediately after creation or
  ;;       the memory leaks — there is no destructor to call.
  ;;       Use mlir::Region::push_back<Block> which creates and pushes atomically.

  ;; @brief mlir::Block::addArgument — append one typed argument to a block.
  ;; @param block  Block* uptr
  ;; @param type   mlir::Type opaque pointer uptr
  ;; @param loc    mlir::Location opaque pointer uptr
  ;; @return       mlir::BlockArgument opaque pointer uptr (subclass of mlir::Value)
  ;; @see          mlir/IR/Block.h
  (define mlir::Block::addArgument %mlir::Block::addArgument)

  ) ;; end library (mlir IR Block)
