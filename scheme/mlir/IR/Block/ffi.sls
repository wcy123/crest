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
;; (mlir IR Block ffi) — raw C bindings for mlir/IR/Block.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Block ffi)
  (export %mlir::Block::getArgument
          %mlir::Block::getNumArguments
          %mlir::Block::new
          %mlir::Block::addArgument)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::Block::getArgument — return the idx-th block argument.
  ;; @param block  Block* uptr
  ;; @param idx    0-based argument index (int)
  ;; @return       Value opaque pointer uptr; 0 if null or index out of range
  ;; @see          mlir/IR/Block.h
  ;; @note         Defined in lib/Bindings/IR/Block.cpp
  (define %mlir::Block::getArgument
    (foreign-procedure "mlir::Block::getArgument" (uptr int) uptr))

  ;; @brief mlir::Block::getNumArguments — return the number of block arguments.
  ;; @param block  Block* uptr (must be non-null)
  ;; @return       Argument count (uptr)
  ;; @see          mlir/IR/Block.h
  ;; @note         Defined in lib/Bindings/IR/Block.cpp
  (define %mlir::Block::getNumArguments
    (foreign-procedure "mlir::Block::getNumArguments" (uptr) uptr))

  ;; @brief mlir::Block::new — heap-allocate an empty Block.
  ;; @return  Block* uptr — ownership transferred to region on push_back
  ;; @see     mlir/IR/Block.h
  (define %mlir::Block::new
    (foreign-procedure "mlir::Block::new" () uptr))

  ;; @brief mlir::Block::addArgument — append one typed argument to a block.
  ;; @param block  Block* uptr
  ;; @param type   Type opaque pointer uptr
  ;; @param loc    Location opaque pointer uptr
  ;; @return       Value opaque pointer uptr of the new BlockArgument
  ;; @see          mlir/IR/Block.h
  (define %mlir::Block::addArgument
    (foreign-procedure "mlir::Block::addArgument" (uptr uptr uptr) uptr))

  ) ;; end library (mlir IR Block ffi)
