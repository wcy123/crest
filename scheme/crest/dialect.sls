;; Keyword exports — bound to their own symbol so users can write
;; :initialize, :parse-type etc. without quoting in call sites.
(library (crest dialect)
  (export load-scheme-dialect!
          register-dynamic-op!
          define-dialect
          define-op
          :name
          :initialize
          :get-dependent-dialects
          :parse-attribute
          :print-attribute
          :parse-type
          :print-type
          :materialize-constant
          :get-canonicalization-patterns
          :verify-op-attr
          :verify-region-arg-attr
          :verify-region-result-attr
          :get-registered-interface-for-op
          :verify
          :verify-regions
          :parse
          :print
          :fold
          :populate-default-attrs
          :summary
          :description
          :operands
          :attributes
          :results
          :interfaces
          :required
          :optional
          :variadic)
  (import (chezscheme)
          (for (crest dialect expand) expand)        ; generate-op-defs at macro-expansion time
          (for (crest dialect ast) expand run)    ; dialect-parse / op-parse records
          (crest dialect ffi))

  ;; Chez Scheme identifiers starting with ':' are not self-evaluating (unlike
  ;; Common Lisp keywords).  Without these bindings, :keyword in argument
  ;; position is an unbound-identifier error.
  (define :name                        ':name)
  (define :initialize                  ':initialize)
  (define :get-dependent-dialects      ':get-dependent-dialects)
  (define :parse-attribute             ':parse-attribute)
  (define :print-attribute             ':print-attribute)
  (define :parse-type                  ':parse-type)
  (define :print-type                  ':print-type)
  (define :materialize-constant        ':materialize-constant)
  (define :get-canonicalization-patterns ':get-canonicalization-patterns)
  (define :verify-op-attr              ':verify-op-attr)
  (define :verify-region-arg-attr      ':verify-region-arg-attr)
  (define :verify-region-result-attr   ':verify-region-result-attr)
  (define :get-registered-interface-for-op ':get-registered-interface-for-op)
  (define :verify                      ':verify)
  (define :verify-regions              ':verify-regions)
  (define :parse                       ':parse)
  (define :print                       ':print)
  (define :fold                        ':fold)
  (define :populate-default-attrs      ':populate-default-attrs)
  (define :summary                     ':summary)
  (define :description                 ':description)
  (define :operands                    ':operands)
  (define :attributes                  ':attributes)
  (define :results                     ':results)
  (define :required                    ':required)
  (define :optional                    ':optional)
  (define :variadic                    ':variadic)
  (define :interfaces                  ':interfaces)


  ;; Load a Scheme-defined dialect into an existing MLIRContext.
  ;; dialect-name: the dialect namespace string (e.g. "toy").
  ;; module-name:  the Scheme library path (e.g. "toy/ch3/toy").
  ;; Safe to call outside the pass pipeline (multiThreadedExecutionContext == 0).
  (define (load-scheme-dialect! ctx dialect-name module-name)
    (%crest::load-scheme-dialect! ctx dialect-name module-name))

  (define (%%plist->vector n index-fn plist)
    (let ([v (make-vector n #f)])
      (let loop ([rest plist])
        (unless (null? rest)
          (vector-set! v (index-fn (car rest)) (cadr rest))
          (loop (cddr rest))))
      v))

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

  (define (register-dynamic-op! dialect-ptr op-name . callbacks)
    (%crest::register-dynamic-op!
     dialect-ptr
     op-name
     (%%plist->vector 7 %%op-slot-index callbacks)))

  ;; Auxiliary keyword — exported so define-op identifiers in user code
  ;; are free-identifier=? to the literal in parse-clauses.
  (define-syntax define-op
    (lambda (stx)
      (syntax-violation 'define-op "define-op used outside define-dialect" stx)))

  ;; -------------------------------------------------------------------------
  ;; define-dialect — dialect + ops in one declaration (like define-record-type)
  ;;
  ;; (define-dialect toy               ; symbol → MLIR name "toy"
  ;;   (define-op constant             ; op name auto-prefixed → "toy.constant"
  ;;     :attributes ((value  mlir::DenseElementsAttr))
  ;;     :results    ((output mlir::RankedTensorType)))
  ;;   (:parse-type (parser)
  ;;     (my-parse-type parser)))
  ;; -------------------------------------------------------------------------
  (define-syntax define-dialect
    (lambda (stx)
      (define (parse-clauses clauses-stx dialect-id-stx)
        ;; cbs slot order matches CrestDialect::Callbacks — index set directly
        ;; avoids a secondary lookup at call time.
        (let ([ops '()]
              [cbs (make-vector 12 #f)])

          ;; Returns operand-field record.  type is kept as syntax so it resolves
          ;; correctly when used in generated verify code (a predicate, not a symbol).
          (define (parse-op-operand field-stx)
            (syntax-case field-stx (:required :optional :variadic)
              [(name type)
               (identifier? #'name)
               (make-operand-field #'name #'type ':required)]
              [(name type :required)
               (identifier? #'name)
               (make-operand-field #'name #'type ':required)]
              [(name type :optional)
               (identifier? #'name)
               (make-operand-field #'name #'type ':optional)]
              [(name type :variadic)
               (identifier? #'name)
               (make-operand-field #'name #'type ':variadic)]
              [_
               (syntax-violation 'define-op
                                 "malformed operand — expected (name type) or (name type :required/:optional/:variadic)"
                                 field-stx)]))
          ;; Returns attribute-field record — mirrors parse-op-operand for attributes.
          (define (parse-op-attribute field-stx)
            (syntax-case field-stx (:required :optional)
              [(name type)
               (identifier? #'name)
               (make-attribute-field #'name #'type ':required)]
              [(name type :required)
               (identifier? #'name)
               (make-attribute-field #'name #'type ':required)]
              [(name type :optional)
               (identifier? #'name)
               (make-attribute-field #'name #'type ':optional)]
              [_
               (syntax-violation 'define-op
                                 "malformed attribute — expected (name type) or (name type :required/:optional)"
                                 field-stx)]))

          ;; Op callback vector slots (mirrors CrestOp::Callbacks in lib/Crest/Op.h):
          ;;   0  verify                       (op) → bool
          ;;   1  verify-regions               (op) → bool
          ;;   2  parse                        (parser state) → bool  [#f = generic]
          ;;   3  print                        (op printer name) → void [#f = generic]
          ;;   4  fold                         (op) → bool
          ;;   5  get-canonicalization-patterns (pattern-set) → void
          ;;   6  populate-default-attrs       (op-name attrs) → void
          (define (parse-define-op op-name-stx sub-clauses-stx)
            (let ([operands   '()]
                  [attributes '()]
                  [results    '()]
                  [interfaces '()]
                  [op-cbs     (make-vector 7 #f)])
              (let loop-sub ([stx sub-clauses-stx])
                (syntax-case stx (:summary :description
                                           :operands :attributes :results
                                           :interfaces
                                           :verify :verify-regions
                                           :parse :print :fold
                                           :required :optional
                                           :get-canonicalization-patterns
                                           :populate-default-attrs)
                  [(:summary     _ . rest)  (loop-sub #'rest)]
                  [(:description _ . rest)  (loop-sub #'rest)]
                  [(:interfaces  (iface-spec ...) . rest)
                   (begin
                     (set! interfaces
                           (map (lambda (spec-stx)
                                  (syntax-case spec-stx ()
                                    [(iface-name method-clause ...)
                                     (identifier? #'iface-name)
                                     (make-interface-entry
                                      #'iface-name
                                      (map (lambda (mc)
                                             (syntax-case mc ()
                                               [(mname formals body ...)
                                                (identifier? #'mname)
                                                (make-interface-method
                                                 (syntax->datum #'mname)
                                                 #'formals
                                                 #'(body ...))]
                                               [_
                                                (syntax-violation ':interfaces
                                                                  "expected (method-name (formals...) body...)" mc)]))
                                           (syntax->list #'(method-clause ...))))]
                                    [_
                                     (syntax-violation ':interfaces
                                                       "expected (interface-name method-clause ...)" spec-stx)]))
                                (syntax->list #'(iface-spec ...))))
                     (loop-sub #'rest))]
                  [(:operands    (field ...) . rest)
                   (begin
                     (set! operands (map parse-op-operand (syntax->list #'(field ...))))
                     (loop-sub #'rest))]
                  [(:attributes  (field ...) . rest)
                   (begin
                     (set! attributes (map parse-op-attribute (syntax->list #'(field ...))))
                     (loop-sub #'rest))]
                  [(:results     ((name type) ...) . rest)
                   (andmap identifier? (syntax->list #'(name ...)))
                   (begin (set! results
                                (map make-result-field
                                     (syntax->list #'(name ...))
                                     (syntax->list #'(type ...))))
                          (loop-sub #'rest))]
                  [((:verify                       (op) body ...) . rest)
                   (identifier? #'op)
                   (begin (vector-set! op-cbs 0 #'(lambda (op) body ...))
                          (loop-sub #'rest))]
                  [((:verify-regions               (op) body ...) . rest)
                   (identifier? #'op)
                   (begin (vector-set! op-cbs 1 #'(lambda (op) body ...))
                          (loop-sub #'rest))]
                  [((:parse                        (parser state) body ...) . rest)
                   (and (identifier? #'parser) (identifier? #'state))
                   (begin (vector-set! op-cbs 2 #'(lambda (parser state) body ...))
                          (loop-sub #'rest))]
                  [((:print                        (op printer name) body ...) . rest)
                   (and (identifier? #'op) (identifier? #'printer) (identifier? #'name))
                   (begin (vector-set! op-cbs 3 #'(lambda (op printer name) body ...))
                          (loop-sub #'rest))]
                  [((:fold                         (op) body ...) . rest)
                   (identifier? #'op)
                   (begin (vector-set! op-cbs 4 #'(lambda (op) body ...))
                          (loop-sub #'rest))]
                  [((:get-canonicalization-patterns (pattern-set) body ...) . rest)
                   (identifier? #'pattern-set)
                   (begin (vector-set! op-cbs 5 #'(lambda (pattern-set) body ...))
                          (loop-sub #'rest))]
                  [((:populate-default-attrs       (op-name attrs) body ...) . rest)
                   (and (identifier? #'op-name) (identifier? #'attrs))
                   (begin (vector-set! op-cbs 6 #'(lambda (op-name attrs) body ...))
                          (loop-sub #'rest))]
                  [(bad . _)
                   (syntax-violation 'define-op
                                     "unknown clause — expected :operands, :attributes, :results, :summary, :description, or (:callback (args) body ...)"
                                     #'bad)]
                  [()
                   (make-op-parse op-name-stx operands attributes results op-cbs interfaces)]))))


          (let loop ([stx clauses-stx])
            (syntax-case stx (:summary :description
                                       :initialize :get-dependent-dialects
                                       :parse-attribute :print-attribute
                                       :parse-type :print-type
                                       :materialize-constant
                                       :get-canonicalization-patterns
                                       :verify-op-attr
                                       :verify-region-arg-attr
                                       :verify-region-result-attr
                                       :get-registered-interface-for-op
                                       define-op)
              ;; :summary/:description accepted but produce no runtime effect —
              ;; same placeholder role as in define-op.
              [(:summary     _ . rest) (loop #'rest)]
              [(:description _ . rest) (loop #'rest)]
              [((define-op op-name . op-sub) . rest)
               (identifier? #'op-name)
               (begin
                 (set! ops (cons (parse-define-op #'op-name #'op-sub) ops))
                 (loop #'rest))]
              [((:initialize                  (dialect-ptr) body ...) . rest)
               (identifier? #'dialect-ptr)
               (begin (vector-set! cbs  0 #'(lambda (dialect-ptr) body ...)) (loop #'rest))]
              [((:get-dependent-dialects      () body ...) . rest)
               (begin (vector-set! cbs  1 #'(lambda () body ...)) (loop #'rest))]
              [((:parse-attribute             (parser type) body ...) . rest)
               (and (identifier? #'parser) (identifier? #'type))
               (begin (vector-set! cbs  2 #'(lambda (parser type) body ...)) (loop #'rest))]
              [((:print-attribute             (attr printer) body ...) . rest)
               (and (identifier? #'attr) (identifier? #'printer))
               (begin (vector-set! cbs  3 #'(lambda (attr printer) body ...)) (loop #'rest))]
              [((:parse-type                  (parser) body ...) . rest)
               (identifier? #'parser)
               (begin (vector-set! cbs  4 #'(lambda (parser) body ...)) (loop #'rest))]
              [((:print-type                  (type printer) body ...) . rest)
               (and (identifier? #'type) (identifier? #'printer))
               (begin (vector-set! cbs  5 #'(lambda (type printer) body ...)) (loop #'rest))]
              [((:materialize-constant        (builder value type loc) body ...) . rest)
               (and (identifier? #'builder) (identifier? #'value)
                    (identifier? #'type)    (identifier? #'loc))
               (begin (vector-set! cbs  6 #'(lambda (builder value type loc) body ...)) (loop #'rest))]
              [((:get-canonicalization-patterns (pattern-set) body ...) . rest)
               (identifier? #'pattern-set)
               (begin (vector-set! cbs  7 #'(lambda (pattern-set) body ...)) (loop #'rest))]
              [((:verify-op-attr              (op attr) body ...) . rest)
               (and (identifier? #'op) (identifier? #'attr))
               (begin (vector-set! cbs  8 #'(lambda (op attr) body ...)) (loop #'rest))]
              [((:verify-region-arg-attr      (op region-index arg-index attr) body ...) . rest)
               (and (identifier? #'op)           (identifier? #'region-index)
                    (identifier? #'arg-index)    (identifier? #'attr))
               (begin (vector-set! cbs  9 #'(lambda (op region-index arg-index attr) body ...)) (loop #'rest))]
              [((:verify-region-result-attr   (op region-index result-index attr) body ...) . rest)
               (and (identifier? #'op)           (identifier? #'region-index)
                    (identifier? #'result-index) (identifier? #'attr))
               (begin (vector-set! cbs 10 #'(lambda (op region-index result-index attr) body ...)) (loop #'rest))]
              [((:get-registered-interface-for-op (interface-id op-name) body ...) . rest)
               (and (identifier? #'interface-id) (identifier? #'op-name))
               (begin (vector-set! cbs 11 #'(lambda (interface-id op-name) body ...)) (loop #'rest))]
              [(bad . _)
               (syntax-violation 'define-dialect
                                 "unrecognised clause — expected (define-op ...) or (:keyword (args) body ...)"
                                 #'bad)]
              [()
               (make-dialect-parse dialect-id-stx (reverse ops) cbs)]))))

      (syntax-case stx ()
        [(_ dialect-id clause ...)
         (let* ([dialect      (parse-clauses #'(clause ...) #'dialect-id)]
                [ops          (dialect-parse-ops dialect)]
                [all-op-defs  (generate-all-op-defs #'dialect-id ops)]
                [reg-defs     (generate-register-dialect #'dialect-id (dialect-parse-cbs dialect) ops
                                                         #'%crest::register-dynamic-op!
                                                         #f)])
           (let ([result (with-syntax
                             ([(op-def  ...) all-op-defs]
                              [(reg-def ...) reg-defs])
                           #'(begin reg-def ... op-def ...))])
             (when (getenv "DEBUG_DEFINE_DIALECT")
               (pretty-print (syntax->datum result)))
             result))])
      ))

  )
