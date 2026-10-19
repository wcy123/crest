;; Keyword exports — bound to their own symbol so users can write
;; :initialize, :parse-type etc. without quoting in call sites:
;;   (register-dialect! ctx "toy" :initialize my-fn)   ; works
(library (crest dialect)
  (export register-dialect!
          register-dynamic-op!
          define-dialect
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
          :required
          :optional
          :variadic)
  (import (chezscheme)
          (for (crest op expand)    expand)  ; expand-op-defs at macro-expansion time
          (for (crest dialect ast)  expand run)  ; dialect-parse / op-parse records
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

  (define (register-dialect! ctx name . callbacks)
    (%crest::register-dialect!
     ctx
     name
     (%%plist->vector 12 %%dialect-slot-index callbacks)))

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

      (define (parse-clauses clauses-stx default-name)
        ;; cbs slot order matches CrestDialect::Callbacks — index set directly
        ;; avoids a secondary lookup at call time.
        (let ([ops '()]
              [cbs (make-vector 12 #f)])

          ;; (name type) normalises to (name type :required) so downstream code
          ;; always sees a uniform 3-element form.
          (define (parse-op-operand field-stx)
            (syntax-case field-stx (:required :optional :variadic)
              [(name type)
               (identifier? #'name)
               (syntax->datum #'(name type :required))]
              [(name type :required)
               (identifier? #'name)
               (syntax->datum #'(name type :required))]
              [(name type :optional)
               (identifier? #'name)
               (syntax->datum #'(name type :optional))]
              [(name type :variadic)
               (identifier? #'name)
               (syntax->datum #'(name type :variadic))]
              [_
               (syntax-violation 'define-op
                                 "malformed operand — expected (name type) or (name type :required/:optional/:variadic)"
                                 field-stx)]))

          ;; name already checked by caller.
          ;;
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
                  [op-cbs     (make-vector 7 #f)])
              (let loop-sub ([stx sub-clauses-stx])
                (syntax-case stx (:summary :description
                                           :operands :attributes :results
                                           :verify :verify-regions
                                           :parse :print :fold
                                           :get-canonicalization-patterns
                                           :populate-default-attrs)
                  [(:summary     _ . rest)  (loop-sub #'rest)]
                  [(:description _ . rest)  (loop-sub #'rest)]
                  [(:operands    (field ...) . rest)
                   (begin
                     (set! operands (map parse-op-operand (syntax->list #'(field ...))))
                     (loop-sub #'rest))]
                  [(:attributes  ((name type) ...) . rest)
                   (andmap identifier? (syntax->list #'(name ...)))
                   (begin (set! attributes (syntax->datum #'((name type) ...)))
                          (loop-sub #'rest))]
                  [(:results     ((name type) ...) . rest)
                   (andmap identifier? (syntax->list #'(name ...)))
                   (begin (set! results (syntax->datum #'((name type) ...)))
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
                   (make-op-parse op-name-stx operands attributes results op-cbs)]))))


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
               (make-dialect-parse default-name (reverse ops) cbs)]))))

      (syntax-case stx ()
        [(_ dialect-id clause ...)
         (let* ([dialect-sym  (syntax->datum #'dialect-id)]
                [parsed       (parse-clauses #'(clause ...)
                                             (symbol->string dialect-sym))]
                [dialect-name (dialect-parse-name parsed)]
                [op-clauses   (dialect-parse-ops  parsed)]
                [extra-cbs    (dialect-parse-cbs  parsed)]
                [op-prefix    (string-append dialect-name ".")]
                [make-id      (lambda (sfx)
                                (datum->syntax #'dialect-id (string->symbol sfx)))]
                [init-id      (make-id (string-append
                                        "%%" (symbol->string dialect-sym)
                                        ":initialize"))]
                [register-id  (make-id (string-append
                                        (symbol->string dialect-sym) ":register!"))]
                [op-names     (map (lambda (c)
                                     (string-append op-prefix
                                                    (symbol->string (syntax->datum (op-parse-name c)))))
                                   op-clauses)]
                [all-op-defs  (apply append
                                     (map (lambda (c)
                                            (let* ([full-name (string-append op-prefix
                                                                             (symbol->string (syntax->datum (op-parse-name c))))]
                                                   [plist (append
                                                           (if (null? (op-parse-operands   c)) '() (list ':operands   (op-parse-operands   c)))
                                                           (if (null? (op-parse-attributes c)) '() (list ':attributes (op-parse-attributes c)))
                                                           (if (null? (op-parse-results    c)) '() (list ':results    (op-parse-results    c))))])
                                              (expand-op-defs #'dialect-id full-name plist)))
                                          op-clauses))]
                ;; Slot 0 (:initialize) skipped — %%init is always the initializer.
                [%%slot-keywords
                 '#(:initialize :get-dependent-dialects
                                :parse-attribute :print-attribute
                                :parse-type :print-type :materialize-constant
                                :get-canonicalization-patterns :verify-op-attr
                                :verify-region-arg-attr :verify-region-result-attr
                                :get-registered-interface-for-op)]
                [extra-kv-list
                 (let loop ([i 1] [acc '()])   ; start at 1, skip :initialize
                   (if (= i 12)
                       (reverse acc)
                       (let ([v (vector-ref extra-cbs i)])
                         (if (not v)
                             (loop (+ i 1) acc)
                             (loop (+ i 1)
                                   (cons v
                                         (cons (datum->syntax #'dialect-id
                                                              `(quote ,(vector-ref %%slot-keywords i)))
                                               acc)))))))])

           (with-syntax
               ([%%init            init-id]
                [dialect:register! register-id]
                [dialect-name-str  dialect-name]
                [(op-def ...)      all-op-defs]
                [(op-name-str ...) (map (lambda (n) (datum->syntax #'dialect-id n))
                                        op-names)]
                [(extra-kv ...)    extra-kv-list])
             #'(begin
                 op-def ...

                 ;; dialect-ptr is the CrestDialect* passed by C++ as `this` when
                 ;; the dialect is first loaded — it arrives from the C++ side,
                 ;; not from any Scheme binding.
                 (define (%%init dialect-ptr)
                   (register-dynamic-op! dialect-ptr op-name-str) ...)

                 ;; extra-kv ... splices user-provided dialect callbacks before
                 ;; :initialize so all 12 CrestDialect slots can be populated.
                 (define (dialect:register! ctx)
                   (register-dialect! ctx dialect-name-str
                                      extra-kv ...
                                      ':initialize %%init)))))]))
    ))
