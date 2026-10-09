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
    %mlir::Region::push_back
    %mlir::Region::getParentOp
    %mlir::Region::front
    %mlir::Block::new)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %mlir::Block::new
    (foreign-procedure "mlir::Block::new" () uptr))

  (define %mlir::Region::push_back
    (foreign-procedure "mlir::Region::push_back" (uptr uptr) void))

  (define %mlir::Region::getParentOp
    (foreign-procedure "mlir::Region::getParentOp" (uptr) uptr))

  (define %mlir::Region::front
    (foreign-procedure "mlir::Region::front" (uptr) uptr))

  ) ;; end library (mlir IR Region ffi)
