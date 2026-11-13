#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Dialect Affine IR AffineOps) — Public API for
;; mlir/Dialect/Affine/IR/AffineOps.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Dialect Affine IR AffineOps)
  (export mlir::affine::buildAffineLoopNest
          mlir::affine::AffineLoadOp::create
          mlir::affine::AffineStoreOp::create
          mlir::affine::AffineLoadOp::create<AffineMap>
          mlir::affine::AffineStoreOp::create<AffineMap>
          mlir::DialectRegistry::insert<mlir::affine::AffineDialect>)
  (import (rnrs)
          (crest callback)
          (only (crest support array-ref) crest::CArrayRef->list)
          (mlir Dialect Affine IR AffineOps ffi))

  ;; @brief buildAffineLoopNest: build a nest of loops with constant bounds and steps, and call
  ;;        BODY inside the innermost one.
  ;; @param builder  a builder shell
  ;; @param loc      Location uptr
  ;; @param lbs ubs steps  lists of integers, one per loop
  ;; @param body     an expression for a procedure (nested-builder loc ivs): the builder shell for the
  ;;                 body (valid during the call) and the list of the induction variables. It is a C
  ;;                 function for the length of the call, released when the call returns, also on an
  ;;                 error. MLIR's callback is void, so an error of the procedure ends the process with
  ;;                 the text of the error.
  ;; @note           A macro.
  (define-syntax mlir::affine::buildAffineLoopNest
    (syntax-rules ()
      [(_ builder loc lbs ubs steps body)
       (with-c-callable/lambda (c-body (uptr uptr uptr) void
                                       (let ([user body])
                                         (lambda (nested-builder nested-loc ivs)
                                           (user nested-builder nested-loc
                                                 (crest::CArrayRef->list ivs)))))
         (%mlir::affine::buildAffineLoopNest builder loc lbs ubs steps c-body))]))

  (define mlir::affine::AffineLoadOp::create
    %mlir::affine::AffineLoadOp::create)

  (define mlir::affine::AffineStoreOp::create
    %mlir::affine::AffineStoreOp::create)

  (define mlir::affine::AffineLoadOp::create<AffineMap>
    %mlir::affine::AffineLoadOp::create<AffineMap>)

  (define mlir::affine::AffineStoreOp::create<AffineMap>
    %mlir::affine::AffineStoreOp::create<AffineMap>)

  (define mlir::DialectRegistry::insert<mlir::affine::AffineDialect>
    %mlir::DialectRegistry::insert<mlir::affine::AffineDialect>)

  ) ;; end library (mlir Dialect Affine IR AffineOps)
