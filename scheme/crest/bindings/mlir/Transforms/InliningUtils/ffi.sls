#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Transforms/InliningUtils.h
(library (mlir Transforms InliningUtils ffi)
  (export %mlir::DialectInlinerInterface
          %mlir::createInlinerPass)
  (import (chezscheme))

  (define %mlir::DialectInlinerInterface
    (foreign-procedure "mlir::DialectInlinerInterface"
                       (uptr scheme-object) void))

  (define %mlir::createInlinerPass
    (foreign-procedure "mlir::createInlinerPass" () uptr))

  ) ;; end library (mlir Transforms InliningUtils ffi)
