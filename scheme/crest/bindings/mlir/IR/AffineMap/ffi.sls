#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/AffineMap.h
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR AffineMap ffi) — raw C bindings for mlir/IR/AffineMap.h.
;;
;; % prefix = raw C binding. Prefer (mlir IR AffineMap) for normal use.
;; An AffineMap is passed as its opaque pointer uptr; it is context-owned, do NOT free.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR AffineMap ffi)
  (export
    %mlir::AffineMap::getMultiDimIdentityMap
    %mlir::AffineMap::getConstantMap
    %mlir::AffineMap::get)
  (import (rnrs)
          (mlir support foreign) (only (chezscheme) foreign-procedure))

  ;; @param ctx       mlir::MLIRContext* uptr
  ;; @param num-dims  number of dimensions
  ;; @return          AffineMap opaque pointer uptr: (d0, ..., dn-1) -> (d0, ..., dn-1)
  (define %mlir::AffineMap::getMultiDimIdentityMap
    (crest-foreign-procedure "mlir::AffineMap::getMultiDimIdentityMap" (uptr uptr) uptr))

  ;; @param ctx  mlir::MLIRContext* uptr
  ;; @param val  Scheme exact integer mapped to int64_t
  ;; @return     AffineMap opaque pointer uptr: () -> (val)
  (define %mlir::AffineMap::getConstantMap
    (crest-foreign-procedure "mlir::AffineMap::getConstantMap" (uptr integer-64) uptr))

  ;; @brief AffineMap::get(dimCount, symbolCount, results, ctx).
  ;; @param ctx           mlir::MLIRContext* uptr
  ;; @param dim-count     number of dimensions
  ;; @param symbol-count  number of symbols
  ;; @param results       Scheme list of AffineExpr opaque pointers (empty: no results)
  ;; @return              AffineMap opaque pointer uptr
  (define %mlir::AffineMap::get
    (crest-foreign-procedure "mlir::AffineMap::get" (uptr uptr uptr scheme-object) uptr))

  ) ;; end library (mlir IR AffineMap ffi)
