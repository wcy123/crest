#!r6rs
;;===----------------------------------------------------------------------===;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects func) — func dialect populate helpers.
;;
;; Registers conversion patterns that lower func/return ops so that
;; function signatures and return values are updated by the TypeConverter.
;;
;;===----------------------------------------------------------------------===;;
(library (mlir dialects func)
  (export
    mlir-populate-func-type-conversion-pattern)
  (import (chezscheme))

  ;; Register the pattern that rewrites func.func signatures via the TypeConverter.
  ;; patterns:       RewritePatternSet* uptr — pattern added in-place
  ;; type-converter: TypeConverter* uptr
  ;; (2 args — no ctx needed; the TypeConverter carries sufficient context.)
  (define mlir-populate-func-type-conversion-pattern
    (foreign-procedure "mlir_populate_func_type_conversion_pattern" (uptr uptr) void))

) ;; end library (mlir dialects func)
