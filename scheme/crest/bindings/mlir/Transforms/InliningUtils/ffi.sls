#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Transforms/InliningUtils.h
(library (mlir Transforms InliningUtils ffi)
  (export %mlir::DialectInlinerInterface::getInterfaceID
          %mlir::DialectInlinerInterface::materializeCallConversion
          %mlir::createInlinerPass)
  (import (chezscheme) (mlir support BuilderBinding))

  ;; () -> uptr: the TypeID of the interface, as the address that the TypeID wraps.
  (define %mlir::DialectInlinerInterface::getInterfaceID
    (foreign-procedure "mlir::DialectInlinerInterface::getInterfaceID" () uptr))

  (define-builder-binding %mlir::DialectInlinerInterface::materializeCallConversion
    "mlir::DialectInlinerInterface::materializeCallConversion" (uptr uptr uptr uptr uptr) uptr)

  (define %mlir::createInlinerPass
    (foreign-procedure "mlir::createInlinerPass" () uptr))

  ) ;; end library (mlir Transforms InliningUtils ffi)
