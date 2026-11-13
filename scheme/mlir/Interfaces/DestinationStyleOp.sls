#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Interfaces DestinationStyleOp) — DestinationStyleOpInterface bindings.
;;
;; Mirrors mlir/Interfaces/DestinationStyleOpInterface.h
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Interfaces DestinationStyleOp)
  (export
    mlir::DestinationStyleOpInterface::getNumDpsInits
    mlir::DestinationStyleOpInterface::getDpsInitOperand)
  (import (rnrs)
          (mlir Interfaces DestinationStyleOp ffi))

  (define mlir::DestinationStyleOpInterface::getNumDpsInits
    %mlir::DestinationStyleOpInterface::getNumDpsInits)

  (define mlir::DestinationStyleOpInterface::getDpsInitOperand
    %mlir::DestinationStyleOpInterface::getDpsInitOperand)

  ) ;; end library (mlir Interfaces DestinationStyleOp)
