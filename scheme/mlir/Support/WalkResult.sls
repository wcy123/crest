#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Support WalkResult) — the values of mlir::WalkResult.
;;
;; Mirrors mlir/Support/WalkResult.h
;;
;; mlir::WalkResult is a class of 4 bytes that holds one enum, { Interrupt, Advance, Skip }, so the
;; values are the numbers of that enum. The visitor of mlir::Operation::walk answers one of them for
;; each op, and walk answers one too. The C++ binding of walk checks the numbers when it registers
;; (lib/Bindings/IR/Operation.cpp), so a change in MLIR is caught at start-up.
;;
;;===----------------------------------------------------------------------===;;
(library (mlir Support WalkResult)
  (export mlir::WalkResult::interrupt
          mlir::WalkResult::advance
          mlir::WalkResult::skip)
  (import (rnrs))

  ;; Stop the walk.
  (define mlir::WalkResult::interrupt 0)
  ;; Go on with the next op.
  (define mlir::WalkResult::advance 1)
  ;; Skip the nested ops of this op that were not visited yet, and go on.
  (define mlir::WalkResult::skip 2)

  ) ;; end library (mlir Support WalkResult)
