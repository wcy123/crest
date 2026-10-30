#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Pass/PassManager.h
(library (mlir Pass PassManager ffi)
  (export %mlir::PassManager::new
          %mlir::PassManager::addPass
          %mlir::PassManager::run!
          %mlir::PassManager::enableVerifier
          %CrestObject::delete)
  (import (chezscheme))

  (define %mlir::PassManager::new
    (foreign-procedure "mlir::PassManager::new" (uptr) uptr))

  (define %mlir::PassManager::addPass
    (foreign-procedure "mlir::PassManager::addPass" (uptr uptr) void))

  (define %mlir::PassManager::run!
    (foreign-procedure "mlir::PassManager::run!" (uptr uptr) int))

  (define %mlir::PassManager::enableVerifier
    (foreign-procedure "mlir::PassManager::enableVerifier" (uptr int) void))

  (define %CrestObject::delete
    (foreign-procedure "CrestObject::delete" (uptr) void))

  ) ;; end library (mlir Pass PassManager ffi)
