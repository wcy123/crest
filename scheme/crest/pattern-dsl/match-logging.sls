#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest pattern-dsl match-logging) — unified match-failure/exception logging.
;;
;; warn-match : msg op → void
;;   Logs msg at warning level, then "  actual: <mlir-op>" if op is non-zero.
;;   Single entry point for all debug-match and always-on exception output.
;;
;;===----------------------------------------------------------------------===;;

(library (crest pattern-dsl match-logging)
  (export warn-match)
  (import (rnrs)
          (only (mlir support logging) crest::logging::warning)
          (only (mlir IR Operation) mlir::Operation::print))

  (define (warn-match msg op)
    (crest::logging::warning msg)
    (when (not (zero? op))
      (crest::logging::warning
       (string-append "  actual: " (mlir::Operation::print op)))))

  ) ;; end library (crest pattern-dsl match-logging)
