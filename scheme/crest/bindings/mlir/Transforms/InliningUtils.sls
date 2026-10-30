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
          mlir::createInlinerPass)
  (import (rnrs)
          (mlir Transforms InliningUtils ffi))

  (define mlir::DialectInlinerInterface %mlir::DialectInlinerInterface)

  (define mlir::createInlinerPass %mlir::createInlinerPass)

  ) ;; end library (mlir Transforms InliningUtils)
