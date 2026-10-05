#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir value) — mlir/IR/Value.h user-visible API.
;;
;; Function names follow the C++ method names without the class prefix.
;; Users may add a prefix (mlir-ir-value-, value-, etc.) as desired.
;;
;; Raw C bindings live in (mlir ir value ffi) with % prefix.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir value)
  (export
    get-defining-op
    block-argument?
    get-result-number
    num-uses
    get-type)

  (import (rnrs)
          (mlir ir value ffi))

  ;; mlir::Value::getDefiningOp() — returns Operation* or 0 for block args.
  (define get-defining-op %get-defining-op)

  ;; mlir::isa<BlockArgument>(val) — returns #t/#f.
  (define (block-argument? val)
    (= 1 (%block-argument? val)))

  ;; mlir::OpResult::getResultNumber() — returns -1 for block arguments.
  (define get-result-number %get-result-number)

  ;; Use count.
  (define num-uses %num-uses)

  ;; mlir::Value::getType()
  (define get-type %get-type)

) ;; end library (mlir ir value)
