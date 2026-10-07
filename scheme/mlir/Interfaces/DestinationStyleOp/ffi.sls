#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Interfaces DestinationStyleOp ffi) — Raw C bindings.
;;
;; Mirrors mlir/Interfaces/DestinationStyleOpInterface.h
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Interfaces DestinationStyleOp ffi)
  (export
    %mlir::DestinationStyleOpInterface::getNumDpsInits
    %mlir::DestinationStyleOpInterface::getDpsInitOperand)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %mlir::DestinationStyleOpInterface::getNumDpsInits
    (foreign-procedure "mlir::DestinationStyleOpInterface::getNumDpsInits"
                       (uptr) int))

  (define %mlir::DestinationStyleOpInterface::getDpsInitOperand
    (foreign-procedure "mlir::DestinationStyleOpInterface::getDpsInitOperand"
                       (uptr int) uptr))

  ) ;; end library (mlir Interfaces DestinationStyleOp ffi)
