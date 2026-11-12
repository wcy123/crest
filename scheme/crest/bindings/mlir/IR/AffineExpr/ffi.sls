#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/AffineExpr.h
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR AffineExpr ffi) — raw C bindings for mlir/IR/AffineExpr.h.
;;
;; % prefix = raw C binding. Prefer (mlir IR AffineExpr) for normal use.
;; An AffineExpr is passed as its opaque pointer uptr; it is context-owned, do NOT free.
;; Only the AffineExpr by AffineExpr form of each operator is bound.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR AffineExpr ffi)
  (export
    %mlir::getAffineDimExpr
    %mlir::getAffineSymbolExpr
    %mlir::getAffineConstantExpr
    %mlir::AffineExpr::getContext
    %mlir::AffineExpr::operator+
    %mlir::AffineExpr::operator*
    %mlir::AffineExpr::floorDiv
    %mlir::AffineExpr::ceilDiv
    %mlir::AffineExpr::operator%)
  (import (rnrs)
          (mlir support foreign) (only (chezscheme) foreign-procedure))

  ;; @param ctx       mlir::MLIRContext* uptr
  ;; @param position  dimension position
  (define %mlir::getAffineDimExpr
    (crest-foreign-procedure "mlir::getAffineDimExpr" (uptr uptr) uptr))

  ;; @param ctx       mlir::MLIRContext* uptr
  ;; @param position  symbol position
  (define %mlir::getAffineSymbolExpr
    (crest-foreign-procedure "mlir::getAffineSymbolExpr" (uptr uptr) uptr))

  ;; @param ctx       mlir::MLIRContext* uptr
  ;; @param constant  Scheme exact integer mapped to int64_t
  (define %mlir::getAffineConstantExpr
    (crest-foreign-procedure "mlir::getAffineConstantExpr" (uptr integer-64) uptr))

  ;; @param expr  AffineExpr opaque pointer uptr
  ;; @return      the raw mlir::MLIRContext* uptr
  (define %mlir::AffineExpr::getContext
    (crest-foreign-procedure "mlir::AffineExpr::getContext" (uptr) uptr))

  (define %mlir::AffineExpr::operator+
    (crest-foreign-procedure "mlir::AffineExpr::operator+" (uptr uptr) uptr))
  (define %mlir::AffineExpr::operator*
    (crest-foreign-procedure "mlir::AffineExpr::operator*" (uptr uptr) uptr))
  (define %mlir::AffineExpr::floorDiv
    (crest-foreign-procedure "mlir::AffineExpr::floorDiv" (uptr uptr) uptr))
  (define %mlir::AffineExpr::ceilDiv
    (crest-foreign-procedure "mlir::AffineExpr::ceilDiv" (uptr uptr) uptr))
  (define %mlir::AffineExpr::operator%
    (crest-foreign-procedure "mlir::AffineExpr::operator%" (uptr uptr) uptr))

  ) ;; end library (mlir IR AffineExpr ffi)
