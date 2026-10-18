;; Bridges lib/Crest/Dialect.h — Scheme-defined MLIR dialects
(library (crest dialect)
  (export register-dialect!)
  (import (chezscheme)
          (crest dialect ffi))

  ;; Register a Scheme-defined dialect into the MLIRContext's DialectRegistry.
  ;; dialect-descriptor is a vector of 12 callback slots (#f = use default):
  ;;   0 initialize                       6 materialize-constant
  ;;   1 get-dependent-dialects           7 get-canonicalization-patterns
  ;;   2 parse-attribute                  8 verify-op-attr
  ;;   3 print-attribute                  9 verify-region-arg-attr
  ;;   4 parse-type                      10 verify-region-result-attr
  ;;   5 print-type                      11 get-registered-interface-for-op
  ;;
  ;; Loading is deferred — call (mlir::MLIRContext::getOrLoadDialect ctx name)
  ;; to instantiate the dialect on demand.
  (define (register-dialect! ctx name callbacks)
    (%crest::register-dialect!
     ctx
     (string->cstring name)
     (vector->cptr callbacks))))
