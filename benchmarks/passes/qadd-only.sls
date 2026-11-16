#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes qadd-only) — the hip-fusion pass with its first pattern only, the one that
;; benchmarks/cpp/QAddFusion.cpp writes in C++. The full pass has fifteen patterns, so it
;; cannot be compared with one C++ pattern. The pattern is the one of the sample, unchanged.
;; Find it with CREST_PATH=<repository>/samples:<repository>/benchmarks.
;;
;;===----------------------------------------------------------------------===;;

(library (passes qadd-only)
  (export pass-entry-point)

  (import (except (rnrs) =)
          (crest)
          (passes hip-fusion qadd)
          (only (mlir IR Operation)
                mlir::Operation::getContext)
          (only (mlir IR MLIRContext)
                with-current-MLIRContext))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx
                        :patterns (("hip.quantize_linear" hip-qadd-fusion 10))))))

  ) ;; end library (passes qadd-only)
