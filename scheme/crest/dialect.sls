;; Bridges lib/Crest/Dialect.h — Scheme-defined MLIR dialects
;;
;; Runtime API:  register-dialect!     register-dynamic-op!
;; Macro API:    define-mlir-dialect
(library (crest dialect)
  (export register-dialect!
          register-dynamic-op!
          define-mlir-dialect)
  (import (chezscheme)
          (for (crest op expand) expand)   ; %%expand-op-defs at macro-expansion time
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
  ;; define-mlir-dialect — dialect + ops in one declaration
  ;;
  ;; (define-mlir-dialect toy              ; symbol → MLIR name "toy"
  ;;   [:name "override"]                  ; optional name override
  ;;   (define-op constant                 ; auto-prefixed → "toy.constant"
  ;;     :attributes ((value  mlir::DenseElementsAttr))
  ;;     :results    ((output mlir::RankedTensorType)))
  ;;   (define-op print
  ;;     :operands ((input mlir::Value))))
  ;;
  ;; Generates all accessors/predicates for each op, plus:
  ;;   %%toy:initialize (dialect-ptr)  — auto-registers all ops
  ;;   toy:register!    (ctx)          — registers dialect into MLIRContext
  ;; -------------------------------------------------------------------------
  (define-syntax define-mlir-dialect
    (lambda (stx)
      ;; Step-by-1 scan — clause list mixes (define-op ...) forms with
      ;; :keyword value pairs, so cddr stepping would skip op forms.
      (define (find-name plist default)
        (let loop ([rest plist])
          (cond [(null? rest)              default]
                [(eq? (car rest) ':name)
                 (if (null? (cdr rest)) default (cadr rest))]
                [else                      (loop (cdr rest))])))
      (define (define-op-clause? c)
        (and (pair? c) (eq? (car c) 'define-op)))

      (syntax-case stx ()
        [(_ dialect-sym clause ...)
         (let* ([d-sym      (syntax->datum #'dialect-sym)]
                [plist      (syntax->datum #'(clause ...))]
                [d-str      (find-name plist (symbol->string d-sym))]
                [prefix     (string-append d-str ".")]
                [op-clauses (filter define-op-clause? plist)]
                [op-names   (map (lambda (c)
                                   (string-append prefix
                                                  (symbol->string (cadr c))))
                                 op-clauses)]
                [make-id    (lambda (sfx)
                              (datum->syntax #'dialect-sym
                                             (string->symbol sfx)))]
                [init-id    (make-id (string-append
                                      "%%" (symbol->string d-sym) ":initialize"))]
                [reg-id     (make-id (string-append
                                      (symbol->string d-sym) ":register!"))]
                [all-defs   (apply append
                                   (map (lambda (c)
                                          (%%expand-op-defs
                                           #'dialect-sym
                                           (string-append prefix
                                                          (symbol->string (cadr c)))
                                           (cddr c)))
                                        op-clauses))])
           (with-syntax
               ([%%init      init-id]
                [!register   reg-id]
                [d-name-s    d-str]
                [(op-def ...) all-defs]
                [(op-name-s ...)
                 (map (lambda (n) (datum->syntax #'dialect-sym n))
                      op-names)])
             #'(begin
                 op-def ...
                 (define (%%init dialect-ptr)
                   (register-dynamic-op! dialect-ptr op-name-s) ...)
                 (define (!register ctx)
                   (register-dialect! ctx d-name-s
                                      ':initialize %%init)))))]))
    ))
