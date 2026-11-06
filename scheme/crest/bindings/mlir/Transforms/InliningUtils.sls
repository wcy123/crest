#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Transforms InliningUtils) — Public API for mlir/Transforms/InliningUtils.h.
;;
;; Provides:
;;   mlir::DialectInlinerInterface — register a Scheme-backed inliner interface
;;                                    on a CrestDialect
;;   mlir::createInlinerPass       — create an MLIR inliner pass instance
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Transforms InliningUtils)
  (export mlir::DialectInlinerInterface
          mlir::DialectInlinerInterface::materializeCallConversion
          mlir::createInlinerPass)
  (import (rnrs)
          (mlir Transforms InliningUtils ffi))

  (define mlir::DialectInlinerInterface %mlir::DialectInlinerInterface)

  ;; @brief materializeCallConversion on the dialect's inliner interface: creates the op that
  ;; bridges a call operand of one type to a parameter of another.
  ;; @param builder      builder shell (any kind)
  ;; @param dialect      mlir::Dialect* uptr
  ;; @param input        mlir::Value uptr
  ;; @param result-type  mlir::Type uptr
  ;; @param loc          mlir::Location uptr
  ;; @return             mlir::Operation* uptr, or 0 when none
  (define mlir::DialectInlinerInterface::materializeCallConversion
    %mlir::DialectInlinerInterface::materializeCallConversion)

  (define mlir::createInlinerPass %mlir::createInlinerPass)

  ) ;; end library (mlir Transforms InliningUtils)
