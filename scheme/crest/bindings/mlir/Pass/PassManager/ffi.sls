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
          %mlir::PassManager::nest
          %mlir::OpPassManager::addPass)
  (import (chezscheme)
          (mlir support foreign))

  (define %mlir::PassManager::new
    (crest-foreign-procedure "mlir::PassManager::new" (uptr) uptr))

  (define %mlir::PassManager::addPass
    (crest-foreign-procedure "mlir::PassManager::addPass" (uptr uptr) void))

  (define %mlir::PassManager::run!
    (crest-foreign-procedure "mlir::PassManager::run!" (uptr uptr) int))

  (define %mlir::PassManager::enableVerifier
    (crest-foreign-procedure "mlir::PassManager::enableVerifier" (uptr int) void))

  (define %mlir::PassManager::nest
    (crest-foreign-procedure "mlir::PassManager::nest" (uptr string) uptr))

  (define %mlir::OpPassManager::addPass
    (crest-foreign-procedure "mlir::OpPassManager::addPass" (uptr uptr) void))

  ) ;; end library (mlir Pass PassManager ffi)
