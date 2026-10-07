#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Region ffi) — Raw C bindings for mlir::Region and mlir::Block lifecycle.
;;
;; Mirrors mlir/IR/Region.h
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Region ffi)
  (export
    %mlir::Block::new
    %mlir::Region::push_back
    %mlir::Block::addArgument
    %mlir::Region::getParentOp
    %mlir::Region::front)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %mlir::Block::new
    (foreign-procedure "mlir::Block::new" () uptr))

  (define %mlir::Region::push_back
    (foreign-procedure "mlir::Region::push_back" (uptr uptr) void))

  (define %mlir::Block::addArgument
    (foreign-procedure "mlir::Block::addArgument" (uptr uptr uptr) uptr))

  (define %mlir::Region::getParentOp
    (foreign-procedure "mlir::Region::getParentOp" (uptr) uptr))

  (define %mlir::Region::front
    (foreign-procedure "mlir::Region::front" (uptr) uptr))

  ) ;; end library (mlir IR Region ffi)
