;; Keyword exports — bound to their own symbol so users can write
;; :initialize, :parse-type etc. without quoting in call sites.
(library (crest dialect)
  (export load-scheme-dialect!
          define-dialect
          define-op
          define-type
          fold-attribute
          fold-value
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
          :traits
          :assembly-format
          :required
          :optional
          :buildable-type
          :variadic)
  (import (chezscheme)
          (for (crest dialect expand) expand)        ; generate-op-defs at macro-expansion time
          (for (crest dialect assembly-format) expand)
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
  (define :buildable-type              ':buildable-type)
  (define :variadic                    ':variadic)
  (define :interfaces                  ':interfaces)
  (define :traits                      ':traits)
  (define :assembly-format             ':assembly-format)


  ;; ctx: CrestBox<MLIRContext>* | MLIRContext*
  ;; module-name: slash-separated library path (e.g. "toy/ch3/toy")
  ;; The results of a :fold callback: (fold-value v) is an operand (or other existing value) the op
  ;; folds to, (fold-attribute a) a constant the dialect's :materialize-constant turns into an op.
  (define (fold-value v) (cons 'value v))
  (define (fold-attribute a) (cons 'attribute a))

  ;; Safe outside the pass pipeline (multiThreadedExecutionContext == 0).
  (define (load-scheme-dialect! ctx dialect-name module-name)
    (%crest::load-scheme-dialect! ctx dialect-name module-name))

  ;; Stub so define-op used outside define-dialect gives a clear error,
  ;; and so identifiers in user code are free-identifier=? to the literal
  ;; in parse-clauses.
  (define-syntax define-op
    (lambda (stx)
      (syntax-violation 'define-op "define-op used outside define-dialect" stx)))

  (define-syntax define-type
    (lambda (stx)
      (syntax-violation 'define-type "define-type used outside define-dialect" stx)))

  ;; define-dialect — define an MLIR dialect entirely in Scheme.
  ;; See docs/manual.md §7 "define-dialect reference" for full documentation,
  ;; clause reference, and worked examples.
  (define-syntax define-dialect
    (lambda (stx)

      ;; The entries of an :interfaces clause, of an op or of the dialect: each is
      ;; (interface-name method-clause ...), and is used as it was written: the interface name is a
      ;; macro of the library of the interface, which makes the pair of the TypeID of the interface
      ;; and the dispatcher of C of its clauses.
      (define (%%interface-entries who clause-stx entries-stx)
        (let ([entries (syntax->list entries-stx)])
          (unless (and entries
                       (andmap (lambda (entry)
                                 (syntax-case entry ()
                                   [(iface-name method-clause ...) (identifier? #'iface-name) #t]
                                   [_ #f]))
                               entries))
            (syntax-violation who
                              ":interfaces expects a list of (interface-name method-clause ...)"
                              clause-stx))
          entries))

      (define (parse-clauses clauses-stx dialect-id-stx)
        ;; cbs slot order matches CrestDialect::Callbacks — index set directly
        ;; avoids a secondary lookup at call time.
        (let ([ops '()]
              [types '()]
              [cbs (make-vector 11 #f)])

          ;; (define-type name clause ...): verify / parse / print of a dialect type, over its
          ;; list of attribute parameters.
          (define (parse-define-type name-stx clauses-stx)
            (let ([tcbs (make-vector 3 #f)])
              (let loop-type ([stx clauses-stx])
                (syntax-case stx (:summary :description :verify :parse :print)
                  [(:summary _ . rest)     (loop-type #'rest)]
                  [(:description _ . rest) (loop-type #'rest)]
                  [((:verify (params) body ...) . rest)
                   (identifier? #'params)
                   (begin (vector-set! tcbs 0 #'(lambda (params) body ...)) (loop-type #'rest))]
                  [((:parse (parser) body ...) . rest)
                   (identifier? #'parser)
                   (begin (vector-set! tcbs 1 #'(lambda (parser) body ...)) (loop-type #'rest))]
                  [((:print (printer params) body ...) . rest)
                   (and (identifier? #'printer) (identifier? #'params))
                   (begin (vector-set! tcbs 2 #'(lambda (printer params) body ...)) (loop-type #'rest))]
                  [(bad . _)
                   (syntax-violation 'define-type
                                     "unknown clause: expected (:verify (params) ...), (:parse (parser) ...) or (:print (printer params) ...)"
                                     #'bad)]
                  [() (make-type-parse name-stx tcbs)]))))

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
            ;; The type keyword of :buildable-type, as the shorthands of an op-form name a type.
            (define (buildable key-stx)
              (let ([key (syntax->datum key-stx)])
                (unless (memq key '(:i8 :i16 :i32 :i64 :f32 :f64 :index))
                  (syntax-violation 'define-op
                                    ":buildable-type expects :i8, :i16, :i32, :i64, :f32, :f64 or :index"
                                    field-stx key-stx))
                key))
            (syntax-case field-stx (:required :optional :buildable-type)
              [(name type)
               (identifier? #'name)
               (make-attribute-field #'name #'type ':required #f)]
              [(name type :required)
               (identifier? #'name)
               (make-attribute-field #'name #'type ':required #f)]
              [(name type :optional)
               (identifier? #'name)
               (make-attribute-field #'name #'type ':optional #f)]
              [(name type :buildable-type key)
               (identifier? #'name)
               (make-attribute-field #'name #'type ':required (buildable #'key))]
              [(name type :required :buildable-type key)
               (identifier? #'name)
               (make-attribute-field #'name #'type ':required (buildable #'key))]
              [(name type :optional :buildable-type key)
               (identifier? #'name)
               (make-attribute-field #'name #'type ':optional (buildable #'key))]
              [_
               (syntax-violation 'define-op
                                 "malformed attribute — expected (name type), (name type :required/:optional) or either with :buildable-type :i64 (or another type keyword) at the end"
                                 field-stx)]))

          ;; Op callback vector slots (mirrors CrestOp::Callbacks in lib/Crest/Op.h):
          ;;   0  verify                       (op) → bool
          ;;   1  verify-regions               (op) → bool
          ;;   2  parse                        (parser state) → bool  [#f = generic]
          ;;   3  print                        (op printer name) → void [#f = generic]
          ;;   4  fold                         (op operand-attributes) → #f | list of fold results
          ;;   5  get-canonicalization-patterns (pattern-set) → void
          ;;   6  populate-default-attrs       (op-name attrs) → void
          (define (parse-define-op op-name-stx sub-clauses-stx)
            (let ([operands   '()]
                  [attributes '()]
                  [results    '()]
                  [interfaces #f]
                  [assembly-format #f]
                  [op-cbs     (make-vector 8 #f)]
                  [seen       '()])
              ;; A clause is given once: the second would silently replace the first.
              (define (once! key clause)
                (when (memq key seen)
                  (syntax-violation 'define-op (string-append "repeated " (symbol->string key)) clause))
                (set! seen (cons key seen)))
              (let loop-sub ([stx sub-clauses-stx])
                (syntax-case stx (:summary :description
                                           :operands :attributes :results
                                           :interfaces :traits :assembly-format
                                           :verify :verify-regions
                                           :parse :print :fold
                                           :required :optional
                                           :get-canonicalization-patterns
                                           :populate-default-attrs)
                  [(:summary     _ . rest)  (loop-sub #'rest)]
                  [(:description _ . rest)  (loop-sub #'rest)]
                  [(:interfaces (entry ...) . rest)
                   (begin
                     (when interfaces
                       (syntax-violation 'define-op "repeated :interfaces" (car (syntax->list stx))))
                     (set! interfaces
                           (%%interface-entries 'define-op (car (syntax->list stx))
                                                #'(entry ...)))
                     (loop-sub #'rest))]
                  [(:interfaces . _)
                   (syntax-violation 'define-op
                                     ":interfaces expects a list of (interface-name method-clause ...)"
                                     (car (syntax->list stx)))]
                  [(:assembly-format format . rest)
                   (string? (syntax->datum #'format))
                   (begin
                     (when assembly-format
                       (syntax-violation 'define-op "repeated :assembly-format" #'format))
                     (set! assembly-format #'format)
                     (loop-sub #'rest))]
                  [(:assembly-format . _)
                   (syntax-violation 'define-op ":assembly-format expects a format string"
                                     (car (syntax->list stx)))]
                  [(:traits (trait ...) . rest)
                   (andmap (lambda (t)
                             (syntax-case t ()
                               [name (identifier? #'name) #t]
                               [(name arg ...)
                                (and (identifier? #'name)
                                     (andmap (lambda (a) (or (identifier? a)
                                                             (string? (syntax->datum a))))
                                             (syntax->list #'(arg ...))))
                                #t]
                               [_ #f]))
                           (syntax->list #'(trait ...)))
                   (begin
                     (when (vector-ref op-cbs 7)
                       (syntax-violation 'define-op "repeated :traits" (car (syntax->list stx))))
                     (vector-set! op-cbs 7
                                  (with-syntax
                                      ([(spec ...)
                                        (map (lambda (t)
                                               (let ([parts (if (identifier? t) (list t) (syntax->list t))])
                                                 (with-syntax ([(part ...)
                                                                (map (lambda (x)
                                                                       (let ([d (syntax->datum x)])
                                                                         (if (string? d) d (symbol->string d))))
                                                                     parts)])
                                                   #'(list part ...))))
                                             (syntax->list #'(trait ...)))])
                                    #'(list spec ...)))
                     (loop-sub #'rest))]
                  [(:traits . _)
                   (syntax-violation 'define-op ":traits expects a list of trait names"
                                     (car (syntax->list stx)))]
                  [(:operands    (field ...) . rest)
                   (begin
                     (once! ':operands (car (syntax->list stx)))
                     (set! operands (map parse-op-operand (syntax->list #'(field ...))))
                     (loop-sub #'rest))]
                  [(:attributes  (field ...) . rest)
                   (begin
                     (once! ':attributes (car (syntax->list stx)))
                     (set! attributes (map parse-op-attribute (syntax->list #'(field ...))))
                     (loop-sub #'rest))]
                  [(:results     ((name type) ...) . rest)
                   (andmap identifier? (syntax->list #'(name ...)))
                   (begin (once! ':results (car (syntax->list stx)))
                          (set! results
                                (map make-result-field
                                     (syntax->list #'(name ...))
                                     (syntax->list #'(type ...))))
                          (loop-sub #'rest))]
                  [((:verify                       (op) body ...) . rest)
                   (identifier? #'op)
                   (begin (once! ':verify (car (syntax->list stx)))
                          (vector-set! op-cbs 0 #'(lambda (op) body ...))
                          (loop-sub #'rest))]
                  [((:verify-regions               (op) body ...) . rest)
                   (identifier? #'op)
                   (begin (once! ':verify-regions (car (syntax->list stx)))
                          (vector-set! op-cbs 1 #'(lambda (op) body ...))
                          (loop-sub #'rest))]
                  [((:parse                        (parser state) body ...) . rest)
                   (and (identifier? #'parser) (identifier? #'state))
                   (begin (once! ':parse (car (syntax->list stx)))
                          (vector-set! op-cbs 2 #'(lambda (parser state) body ...))
                          (loop-sub #'rest))]
                  [((:print                        (op printer name) body ...) . rest)
                   (and (identifier? #'op) (identifier? #'printer) (identifier? #'name))
                   (begin (once! ':print (car (syntax->list stx)))
                          (vector-set! op-cbs 3 #'(lambda (op printer name) body ...))
                          (loop-sub #'rest))]
                  [((:fold                         (op operand-attributes) body ...) . rest)
                   (and (identifier? #'op) (identifier? #'operand-attributes))
                   (begin (once! ':fold (car (syntax->list stx)))
                          (vector-set! op-cbs 4 #'(lambda (op operand-attributes) body ...))
                          (loop-sub #'rest))]
                  [((:fold . _) . rest)
                   (syntax-violation 'define-op
                                     "expected (:fold (op operand-attributes) body ...)"
                                     (car (syntax->list stx)))]
                  [((:get-canonicalization-patterns (pattern-set) body ...) . rest)
                   (identifier? #'pattern-set)
                   (begin (once! ':get-canonicalization-patterns (car (syntax->list stx)))
                          (vector-set! op-cbs 5 #'(lambda (pattern-set) body ...))
                          (loop-sub #'rest))]
                  [((:populate-default-attrs       (op-name attrs) body ...) . rest)
                   (and (identifier? #'op-name) (identifier? #'attrs))
                   (begin (once! ':populate-default-attrs (car (syntax->list stx)))
                          (vector-set! op-cbs 6 #'(lambda (op-name attrs) body ...))
                          (loop-sub #'rest))]
                  [(bad . _)
                   (syntax-violation 'define-op
                                     "unknown clause — expected :operands, :attributes, :results, :summary, :description, or (:callback (args) body ...)"
                                     #'bad)]
                  [()
                   ;; (a syntax-case clause is a fender and one expression: the checks are the fender)
                   (begin
                     (when assembly-format
                       (when (or (vector-ref op-cbs 2) (vector-ref op-cbs 3))
                         (syntax-violation 'define-op
                                           ":assembly-format cannot be combined with :parse or :print"
                                           assembly-format))
                       (let-values ([(parse print)
                                     (generate-assembly-format
                                      assembly-format operands attributes results
                                      (exists (lambda (entry)
                                                (eq? (syntax->datum (car (syntax->list entry)))
                                                     'mlir::InferTypeOpInterface))
                                              (or interfaces '())))])
                         (vector-set! op-cbs 2 parse)
                         (vector-set! op-cbs 3 print)))
                     (unless assembly-format
                       (for-each (lambda (field)
                                   (when (attribute-field-buildable-type field)
                                     (syntax-violation 'define-op
                                                       ":buildable-type is the type an :assembly-format gives the attribute; the op has none"
                                                       (attribute-field-name field))))
                                 attributes)))
                   (make-op-parse op-name-stx operands attributes results op-cbs
                                  (or interfaces '()))]))))


          (let ([dialect-ifaces '()])
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
                                         :interfaces
                                         define-op define-type)
                ;; :summary/:description accepted but produce no runtime effect —
                ;; same placeholder role as in define-op.
                [(:summary     _ . rest) (loop #'rest)]
                [(:description _ . rest) (loop #'rest)]
                [((define-type type-name . type-sub) . rest)
                 (identifier? #'type-name)
                 (begin
                   (set! types (cons (parse-define-type #'type-name #'type-sub) types))
                   (loop #'rest))]
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
                ;; Dialect-level interfaces — the same entries as the :interfaces clause of an op.
                ;; Each is (interface-name method-clause ...) where method-clause
                ;; is (method-name (formals) body ...).
                [((:interfaces (entry ...)) . rest)
                 (begin
                   (set! dialect-ifaces
                         (append dialect-ifaces
                                 (%%interface-entries 'define-dialect (car (syntax->list stx))
                                                      #'(entry ...))))
                   (loop #'rest))]
                [((:interfaces . _) . rest)
                 (syntax-violation 'define-dialect
                                   ":interfaces expects a list of (interface-name method-clause ...)"
                                   (car (syntax->list stx)))]
                [(bad . _)
                 (syntax-violation 'define-dialect
                                   "unrecognised clause — expected (define-op ...) or (:keyword (args) body ...)"
                                   #'bad)]
                [()
                 (make-dialect-parse dialect-id-stx (reverse ops) cbs dialect-ifaces (reverse types))])))))

      (syntax-case stx ()
        [(_ dialect-id clause ...)
         (let* ([dialect      (parse-clauses #'(clause ...) #'dialect-id)]
                [ops          (dialect-parse-ops dialect)]
                [types        (dialect-parse-types dialect)]
                [all-op-defs  (generate-all-op-defs #'dialect-id ops)]
                [type-defs    (generate-type-defs #'dialect-id types
                                                  #'%crest::DynamicType::get
                                                  #'%crest::DynamicType::isa
                                                  #'%crest::DynamicType::getParams)]
                [reg-defs     (generate-register-dialect #'dialect-id (dialect-parse-cbs dialect) ops
                                                         #'%crest::register-dynamic-op!
                                                         (dialect-parse-dialect-ifaces dialect)
                                                         types
                                                         #'%crest::register-dynamic-type!)])
           (let ([result (with-syntax
                             ([(op-def  ...) all-op-defs]
                              [(type-def ...) type-defs]
                              [(reg-def ...) reg-defs])
                           #'(begin reg-def ... type-def ... op-def ...))])
             (when (getenv "DEBUG_DEFINE_DIALECT")
               (pretty-print (syntax->datum result)))
             result))])
      ))

  )
