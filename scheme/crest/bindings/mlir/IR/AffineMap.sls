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
;; (mlir IR AffineMap) — mlir::AffineMap constructors.
;;
;; An AffineMap is an opaque pointer uptr, context-owned: valid for the MLIRContext
;; lifetime, do NOT free. Wrap one as an attribute with mlir::AffineMapAttr::get from
;; (mlir IR BuiltinAttributes). The context argument is optional and defaults to
;; (current-MLIRContext).
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR AffineMap)
  (export
    mlir::AffineMap::getMultiDimIdentityMap
    mlir::AffineMap::getConstantMap
    mlir::AffineMap::get)
  (import (rnrs)
          (mlir IR AffineMap ffi)
          (mlir IR AffineExpr)
          (mlir IR MLIRContext))

  ;; @brief mlir::AffineMap::getMultiDimIdentityMap — (d0, ..., dn-1) -> (d0, ..., dn-1).
  ;; @param ctx       mlir::MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @param num-dims  number of dimensions
  (define-ctx-optional mlir::AffineMap::getMultiDimIdentityMap
    %mlir::AffineMap::getMultiDimIdentityMap num-dims)

  ;; @brief mlir::AffineMap::getConstantMap — () -> (val).
  ;; @param ctx  mlir::MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @param val  Scheme exact integer mapped to int64_t
  (define-ctx-optional mlir::AffineMap::getConstantMap
    %mlir::AffineMap::getConstantMap val)

  ;; @brief mlir::AffineMap::get — a map with `dim-count` dimensions, `symbol-count` symbols
  ;; and the given results.
  ;; @param ctx           mlir::MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @param dim-count     number of dimensions
  ;; @param symbol-count  number of symbols
  ;; @param results       list of AffineExprs (from (mlir IR AffineExpr)); an integer is a
  ;;                      constant. The empty list gives a map with no results.
  (define mlir::AffineMap::get
    (case-lambda
     [(dim-count symbol-count results)
      (mlir::AffineMap::get (current-MLIRContext) dim-count symbol-count results)]
     [(ctx dim-count symbol-count results)
      (%mlir::AffineMap::get
       ctx dim-count symbol-count
       (map (lambda (r)
              (mlir::AffineExpr::getAsOpaquePointer
               (if (mlir::AffineExpr? r) r (mlir::getAffineConstantExpr ctx r))))
            results))]))

  ) ;; end library (mlir IR AffineMap)
