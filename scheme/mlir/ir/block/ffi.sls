#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir block ffi) — raw C bindings for mlir/IR/Block.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir block ffi)
  (export %block-get-argument)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %block-get-argument
    (foreign-procedure "mlir_ir_block_get_argument" (uptr int) uptr))

) ;; end library (mlir ir block ffi)
