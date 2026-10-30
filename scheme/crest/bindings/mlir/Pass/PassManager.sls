#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Pass PassManager) — Public API for mlir/Pass/PassManager.h.
;;
;; Provides mlir::PassManager::new, addPass, run!, enableVerifier, and
;; with-PassManager (RAII macro freeing the PassManager after use).
;;
;; Example:
;; @code
;;   (with-PassManager (pm ctx)
;;     (mlir::PassManager::addPass pm (mlir::createInlinerPass))
;;     (mlir::PassManager::run! pm module-op))
;; @endcode
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Pass PassManager)
  (export mlir::PassManager::new
          mlir::PassManager::addPass
          mlir::PassManager::run!
          mlir::PassManager::enableVerifier
          with-PassManager)
  (import (rnrs)
          (mlir Pass PassManager ffi)
          (mlir support RAII))

  (define mlir::PassManager::new %mlir::PassManager::new)

  (define mlir::PassManager::addPass %mlir::PassManager::addPass)

  (define (mlir::PassManager::run! pm module-op)
    (= 1 (%mlir::PassManager::run! pm module-op)))

  (define (mlir::PassManager::enableVerifier pm enabled?)
    (%mlir::PassManager::enableVerifier pm (if enabled? 1 0)))

  (define %%pm-delete %CrestObject::delete)

  ;; RAII macro: binds PM to a fresh PassManager for BODY, then frees it.
  (define-syntax with-PassManager
    (syntax-rules ()
      [(_ (pm ctx) body ...)
       (with-raii (pm (mlir::PassManager::new ctx) %%pm-delete)
         body ...)]))

  ) ;; end library (mlir Pass PassManager)
