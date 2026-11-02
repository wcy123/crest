#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Toy Ch7 StructType public bindings.
(library (mlir Dialect Toy ToyStructType)
  (export toy::StructType::get
          toy::StructType::getElementTypes
          toy::StructType::getNumElementTypes
          toy::StructType?
          toy::StructType::getElementType)
  (import (rnrs)
          (mlir Dialect Toy ToyStructType ffi))

  (define toy::StructType::get          %toy::StructType::get)
  (define toy::StructType::getElementTypes %toy::StructType::getElementTypes)
  (define toy::StructType::getNumElementTypes %toy::StructType::getNumElementTypes)
  (define (toy::StructType? t) (not (zero? (%toy::StructType? t))))
  (define toy::StructType::getElementType %toy::StructType::getElementType)

  ) ;; end library (mlir Dialect Toy ToyStructType)
