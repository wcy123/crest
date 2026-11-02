#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Toy Ch7 StructType FFI bindings.
;; Mirrors lib/Bindings/Dialect/Toy/ToyStructType.cpp
(library (mlir Dialect Toy ToyStructType ffi)
  (export %toy::StructType::get
          %toy::StructType::getElementTypes
          %toy::StructType::getNumElementTypes
          %toy::StructType?
          %toy::StructType::getElementType)
  (import (chezscheme))

  (define %toy::StructType::get
    (foreign-procedure "toy::StructType::get" (scheme-object) uptr))

  (define %toy::StructType::getElementTypes
    (foreign-procedure "toy::StructType::getElementTypes" (uptr) scheme-object))

  (define %toy::StructType::getNumElementTypes
    (foreign-procedure "toy::StructType::getNumElementTypes" (uptr) uptr))

  (define %toy::StructType?
    (foreign-procedure "toy::StructType?" (uptr) int))

  (define %toy::StructType::getElementType
    (foreign-procedure "toy::StructType::getElementType" (uptr uptr) uptr))

  ) ;; end library (mlir Dialect Toy ToyStructType ffi)
