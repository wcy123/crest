;; Bridges lib/Crest/Dialect.h — Scheme-defined MLIR dialects
(library (crest dialect)
  (export register-dialect!
          register-dynamic-op!)
  (import (chezscheme)
          (crest dialect ffi))

  ;; -------------------------------------------------------------------------
  ;; Dialect registration
  ;; -------------------------------------------------------------------------

  ;; Map callback keyword to its slot index (0–11).
  (define (%%dialect-slot-index key)
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

  (define (%%plist->vector n index-fn plist)
    (let ([v (make-vector n #f)])
      (let loop ([rest plist])
        (unless (null? rest)
          (vector-set! v (index-fn (car rest)) (cadr rest))
          (loop (cddr rest))))
      v))

  ;; Register a Scheme-defined dialect with the MLIRContext.
  ;; Callbacks are :keyword proc pairs; omitted callbacks use MLIR defaults.
  ;;
  ;; (register-dialect! ctx "toy"
  ;;   :initialize my-init)
  (define (register-dialect! ctx name . callbacks)
    (%crest::register-dialect!
     ctx
     name
     (%%plist->vector 12 %%dialect-slot-index callbacks)))

  ;; -------------------------------------------------------------------------
  ;; Dynamic op registration
  ;; -------------------------------------------------------------------------

  ;; Map callback keyword to its slot index (0–6).
  (define (%%op-slot-index key)
    (case key
      [(:verify)                         0]
      [(:verify-regions)                 1]
      [(:parse)                          2]
      [(:print)                          3]
      [(:fold)                           4]
      [(:get-canonicalization-patterns)  5]
      [(:populate-default-attrs)         6]
      [else (error "register-dynamic-op!" "unknown callback keyword" key)]))

  ;; Register a dynamic op into a dialect.
  ;; Called from inside the dialect's :initialize callback.
  ;; dialect-ptr: uptr received as the :initialize argument.
  ;;
  ;; (register-dynamic-op! dialect-ptr "toy.constant"
  ;;   :verify my-verify
  ;;   :print  my-print)
  (define (register-dynamic-op! dialect-ptr op-name . callbacks)
    (%crest::register-dynamic-op!
     dialect-ptr
     op-name
     (%%plist->vector 7 %%op-slot-index callbacks))))
