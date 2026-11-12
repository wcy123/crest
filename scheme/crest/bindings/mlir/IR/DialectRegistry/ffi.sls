#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/IR/DialectRegistry.h
(library (mlir IR DialectRegistry ffi)
  (export %mlir::DialectRegistry::new
          %mlir::DialectRegistry::insert)
  (import (chezscheme)
          (mlir support foreign))

  (define %mlir::DialectRegistry::new
    (crest-foreign-procedure "mlir::DialectRegistry::new" () uptr))

  (define %mlir::DialectRegistry::insert
    (crest-foreign-procedure "mlir::DialectRegistry::insert"
                             (uptr string string) void))

  ) ;; end library (mlir IR DialectRegistry ffi)
