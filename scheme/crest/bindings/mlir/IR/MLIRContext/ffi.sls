#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/IR/MLIRContext.h
(library (mlir IR MLIRContext ffi)
  (export
    %mlir::MLIRContext::new
    %mlir::MLIRContext::new/registry
    %mlir::MLIRContext::allowUnregisteredDialects
    %mlir::MLIRContext::allowsUnregisteredDialects
    %mlir::MLIRContext::enableMultithreading
    %mlir::MLIRContext::disableMultithreading
    %mlir::MLIRContext::isMultithreadingEnabled
    %mlir::MLIRContext::getOrLoadDialect
    %mlir::MLIRContext::loadAllAvailableDialects
    %mlir::MLIRContext::printOpOnDiagnostic
    %mlir::MLIRContext::shouldPrintOpOnDiagnostic
    %mlir::MLIRContext::printStackTraceOnDiagnostic
    %mlir::parseSourceFile)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; () → MLIRContext*
  (define %mlir::MLIRContext::new
    (foreign-procedure "mlir::MLIRContext::new" () uptr))

  ;; (DialectRegistry*) → MLIRContext*
  (define %mlir::MLIRContext::new/registry
    (foreign-procedure "mlir::MLIRContext::new/registry" (uptr) uptr))

  ;; (MLIRContext*, bool) → void
  (define %mlir::MLIRContext::allowUnregisteredDialects
    (foreign-procedure "mlir::MLIRContext::allowUnregisteredDialects" (uptr int) void))

  ;; (MLIRContext*) → bool
  (define %mlir::MLIRContext::allowsUnregisteredDialects
    (foreign-procedure "mlir::MLIRContext::allowsUnregisteredDialects" (uptr) int))

  ;; (MLIRContext*, bool) → void
  (define %mlir::MLIRContext::enableMultithreading
    (foreign-procedure "mlir::MLIRContext::enableMultithreading" (uptr int) void))

  ;; (MLIRContext*, bool) → void
  (define %mlir::MLIRContext::disableMultithreading
    (foreign-procedure "mlir::MLIRContext::disableMultithreading" (uptr int) void))

  ;; (MLIRContext*) → bool
  (define %mlir::MLIRContext::isMultithreadingEnabled
    (foreign-procedure "mlir::MLIRContext::isMultithreadingEnabled" (uptr) int))

  ;; (MLIRContext*, ns: string) → Dialect*
  (define %mlir::MLIRContext::getOrLoadDialect
    (foreign-procedure "mlir::MLIRContext::getOrLoadDialect" (uptr string) uptr))

  ;; (MLIRContext*) → void
  (define %mlir::MLIRContext::loadAllAvailableDialects
    (foreign-procedure "mlir::MLIRContext::loadAllAvailableDialects" (uptr) void))

  ;; (MLIRContext*, bool) → void
  (define %mlir::MLIRContext::printOpOnDiagnostic
    (foreign-procedure "mlir::MLIRContext::printOpOnDiagnostic" (uptr int) void))

  ;; (MLIRContext*) → bool
  (define %mlir::MLIRContext::shouldPrintOpOnDiagnostic
    (foreign-procedure "mlir::MLIRContext::shouldPrintOpOnDiagnostic" (uptr) int))

  ;; (MLIRContext*, bool) → void
  (define %mlir::MLIRContext::printStackTraceOnDiagnostic
    (foreign-procedure "mlir::MLIRContext::printStackTraceOnDiagnostic" (uptr int) void))

  ;; (MLIRContext*, filename: string) → Operation* (ModuleOp) or 0
  (define %mlir::parseSourceFile
    (foreign-procedure "mlir::parseSourceFile" (uptr string) uptr))

  ) ;; end library (mlir IR MLIRContext ffi)
