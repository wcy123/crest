;; Bridges lib/Crest/Dialect.h — Scheme-defined MLIR dialects
;;
;; Runtime API:  register-dialect!    register-dynamic-op!
;; Macro API:    define-dialect
(library (crest dialect)
  (export register-dialect!
          register-dynamic-op!
          define-dialect)
  (import (chezscheme)
          (for (crest op expand) expand)   ; expand-op-defs at macro-expansion time
          (crest dialect ffi))

  ;; -------------------------------------------------------------------------
  ;; Dialect registration
  ;; -------------------------------------------------------------------------

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

  ;; (register-dialect! ctx "toy" :initialize my-init)
  (define (register-dialect! ctx name . callbacks)
    (%crest::register-dialect!
     ctx
     name
     (%%plist->vector 12 %%dialect-slot-index callbacks)))

  ;; -------------------------------------------------------------------------
  ;; Dynamic op registration
  ;; -------------------------------------------------------------------------

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

  ;; (register-dynamic-op! dialect-ptr "toy.constant" :verify my-verify)
  (define (register-dynamic-op! dialect-ptr op-name . callbacks)
    (%crest::register-dynamic-op!
     dialect-ptr
     op-name
     (%%plist->vector 7 %%op-slot-index callbacks)))

  ;; -------------------------------------------------------------------------
  ;; define-dialect — dialect + ops in one declaration (like define-record-type)
  ;;
  ;; (define-dialect toy               ; symbol → MLIR name "toy"
  ;;   [:name "override"]              ; optional MLIR name override
  ;;   (define-op constant             ; op name auto-prefixed → "toy.constant"
  ;;     :attributes ((value  mlir::DenseElementsAttr))
  ;;     :results    ((output mlir::RankedTensorType)))
  ;;   (define-op print
  ;;     :operands ((input mlir::Value))))
  ;;
  ;; Generates for each op: predicate, accessors, op-name:register!
  ;; Generates for the dialect:
  ;;   %%<dialect>:initialize — private, registers ops into dialect instance
  ;;   <dialect>:register!   — public, registers dialect into MLIRContext
  ;; -------------------------------------------------------------------------
  (define-syntax define-dialect
    (lambda (stx)

      ;; Scan the clause list one element at a time looking for :name.
      ;; Cannot use cddr stepping because the list mixes :keyword value pairs
      ;; with (define-op ...) forms — cddr would skip an op form.
      (define (dialect-name-from-clauses clauses default)
        (let loop ([rest clauses])
          (cond [(null? rest)              default]
                [(eq? (car rest) ':name)
                 (if (null? (cdr rest)) default (cadr rest))]
                [else                      (loop (cdr rest))])))

      (define (define-op-form? clause)
        (and (pair? clause) (eq? (car clause) 'define-op)))

      (syntax-case stx ()
        [(_ dialect-id clause ...)
         (let* ([all-clauses  (syntax->datum #'(clause ...))]
                [dialect-sym  (syntax->datum #'dialect-id)]
                [dialect-name (dialect-name-from-clauses all-clauses
                                                         (symbol->string dialect-sym))]
                [op-prefix    (string-append dialect-name ".")]
                [op-clauses   (filter define-op-form? all-clauses)]

                ;; Full op name strings, e.g. "toy.constant"
                [op-names     (map (lambda (c)
                                     (string-append op-prefix
                                                    (symbol->string (cadr c))))
                                   op-clauses)]

                ;; Helper: build a Scheme identifier in dialect-id's scope
                [make-id      (lambda (sfx)
                                (datum->syntax #'dialect-id
                                               (string->symbol sfx)))]

                ;; %%<dialect>:initialize — private, not exported by user lib
                [init-id      (make-id (string-append
                                        "%%" (symbol->string dialect-sym)
                                        ":initialize"))]

                ;; <dialect>:register! — public user entry point
                [register-id  (make-id (string-append
                                        (symbol->string dialect-sym)
                                        ":register!"))]

                ;; Expand accessors/predicates for every op
                [all-op-defs  (apply append
                                     (map (lambda (c)
                                            (expand-op-defs
                                             #'dialect-id
                                             (string-append op-prefix
                                                            (symbol->string (cadr c)))
                                             (cddr c)))
                                          op-clauses))])

           (with-syntax
               ([%%init           init-id]
                [dialect:register! register-id]
                [dialect-name-str  dialect-name]
                [(op-def ...)      all-op-defs]
                ;; Syntax objects for each op name string, scoped to dialect-id
                [(op-name-str ...) (map (lambda (n)
                                          (datum->syntax #'dialect-id n))
                                        op-names)])
             #'(begin
                 ;; Accessor and predicate definitions for each op
                 op-def ...

                 ;; Called by CrestDialect::initialize() in C++ when the dialect
                 ;; is first loaded. dialect-ptr is the CrestDialect* (uptr)
                 ;; passed by C++ as `this` — it arrives from the C++ side,
                 ;; not from any Scheme binding.
                 (define (%%init dialect-ptr)
                   (register-dynamic-op! dialect-ptr op-name-str) ...)

                 ;; ': quotes :initialize as a symbol literal — without the
                 ;; quote it would be a free identifier in the template.
                 (define (dialect:register! ctx)
                   (register-dialect! ctx dialect-name-str
                                      ':initialize %%init)))))]))
    ))
