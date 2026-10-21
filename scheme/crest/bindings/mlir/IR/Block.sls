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
          mlir::Block::addArgument
          mlir::Block::empty?
          mlir::Block::back
          mlir::Block::front
          current-MLIRBlock
          with-current-MLIRBlock)
  (import (rnrs)
          (only (chezscheme) make-parameter parameterize)
          (mlir IR Block ffi))

  ;; @brief mlir::Block::getArgument — return the idx-th block argument.
  ;; @param block  Block* uptr
  ;; @param idx    0-based argument index (int)
  ;; @return       mlir::BlockArgument opaque pointer uptr (subclass of mlir::Value)
  ;; @error        raises Scheme error 'mlir::Block::getArgument if null or index out of range
  ;; @see          mlir/IR/Block.h
  ;; @note         bounds check is in C++ — catches even raw %mlir::Block::getArgument callers
  (define mlir::Block::getArgument %mlir::Block::getArgument)

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

  (define (mlir::Block::empty? block) (not (zero? (%mlir::Block::empty block))))
  (define mlir::Block::back  %mlir::Block::back)
  (define mlir::Block::front %mlir::Block::front)

  ;; @brief current-MLIRBlock — dynamic parameter holding the ambient mlir::Block* uptr.
  ;; Installed by with-current-MLIRBlock; used by (:arg N) in begin-mlir-code.
  (define current-MLIRBlock (make-parameter #f))

  ;; @brief with-current-MLIRBlock — install block as current-MLIRBlock for body forms.
  (define-syntax with-current-MLIRBlock
    (syntax-rules ()
      [(_ block body ...)
       (parameterize ([current-MLIRBlock block]) body ...)]))

  ) ;; end library (mlir IR Block)
