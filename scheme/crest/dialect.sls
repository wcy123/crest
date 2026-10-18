;; Bridges lib/Crest/Dialect.h — Scheme-defined MLIR dialects
(library (crest dialect)
  (export register-dialect!)
  (import (chezscheme)
          (crest dialect ffi))

  ;; Map callback keyword to its slot index (0–11) in the vector.
  (define (%%slot-index key)
    (case key
      [(:initialize)                        0]
      [(:get-dependent-dialects)            1]
      [(:parse-attribute)                   2]
      [(:print-attribute)                   3]
      [(:parse-type)                        4]
      [(:print-type)                        5]
      [(:materialize-constant)              6]
      [(:get-canonicalization-patterns)     7]
      [(:verify-op-attr)                    8]
      [(:verify-region-arg-attr)            9]
      [(:verify-region-result-attr)        10]
      [(:get-registered-interface-for-op)  11]
      [else (error "register-dialect!" "unknown callback keyword" key)]))

  ;; Build the 12-slot callback vector from a plist of :keyword proc pairs.
  ;; Unspecified slots default to #f (use ExtensibleDialect default).
  (define (%%plist->callbacks plist)
    (let ([v (make-vector 12 #f)])
      (let loop ([rest plist])
        (unless (null? rest)
          (vector-set! v (%%slot-index (car rest)) (cadr rest))
          (loop (cddr rest))))
      v))

  ;; Register a Scheme-defined dialect with the MLIRContext.
  ;; Callbacks are :keyword proc pairs; omitted callbacks use MLIR defaults.
  ;;
  ;; (register-dialect! ctx "toy"
  ;;   :initialize     my-init
  ;;   :parse-type     my-parse-type)
  (define (register-dialect! ctx name . callbacks)
    (%crest::register-dialect!
     ctx
     name
     (%%plist->callbacks callbacks))))
