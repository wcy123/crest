#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir builtin-types) — MLIR builtin type constructors and queries.
;;
;; Mirrors mlir/IR/BuiltinTypes.h.
;; Imports raw C bindings from (mlir ir builtin-types ffi) and re-exports
;; under clean names. Add Scheme-level helpers here as needed.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir builtin-types)
  (export
    index-type-get
    integer-type-get-i64
    integer-type-get-i1
    ranked-tensor-type?
    ranked-tensor-type-get-rank
    ranked-tensor-type-get-element-type
    ranked-tensor-type-get-shape
    ranked-tensor-type-get-encoding
    ranked-tensor-type-clone-with-encoding)
  (import (rnrs) (mlir ir builtin-types ffi))

  (define index-type-get                    %index-type-get)
  (define integer-type-get-i64             %integer-type-get-i64)
  (define integer-type-get-i1              %integer-type-get-i1)
  (define ranked-tensor-type-get-rank      %ranked-tensor-type-get-rank)
  (define ranked-tensor-type-get-element-type %ranked-tensor-type-get-element-type)
  (define ranked-tensor-type-get-shape     %ranked-tensor-type-get-shape)
  (define ranked-tensor-type-get-encoding  %ranked-tensor-type-get-encoding)
  (define ranked-tensor-type-clone-with-encoding
    %ranked-tensor-type-clone-with-encoding)

  ;; Predicate wrapper: returns #t/#f instead of 1/0
  (define (ranked-tensor-type? type)
    (not (zero? (%ranked-tensor-type-isa type))))

) ;; end library (mlir ir builtin-types)
