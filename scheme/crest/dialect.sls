;; Bridges lib/Crest/Dialect.h — Scheme-defined MLIR dialects
;;
;; Runtime API:  register-dialect!    register-dynamic-op!
;; Macro API:    define-dialect
;;
;; Keyword exports — bound to their own symbol so users can write
;; :initialize, :parse-type etc. without quoting in call sites:
;;   (register-dialect! ctx "toy" :initialize my-fn)   ; works
(library (crest dialect)
  (export register-dialect!
          register-dynamic-op!
          define-dialect
          ;; Dialect callback keywords
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
          ;; Op callback keywords
          :verify
          :verify-regions
          :parse
          :print
          :fold
          :populate-default-attrs
          ;; Shared / define-op keywords
          :summary
          :description
          :operands
          :attributes
          :results)
  (import (chezscheme)
          (for (crest op expand) expand)   ; expand-op-defs at macro-expansion time
          (crest dialect ffi))

  ;; Keywords — each bound to its own symbol value so it is self-evaluating.
  ;; Without these bindings, :keyword in a call position would be an
  ;; unbound-identifier error in Chez Scheme (unlike Common Lisp keywords).
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

      ;; Single-pass clause parser. Returns an alist:
      ;;   ((name . "toy")          — MLIR dialect name string
      ;;    (ops  . (op-stx ...))   — (define-op ...) syntax objects
      ;;    (cbs  . #(stx/#f ...))  — 12-slot vector, slot N = syntax or #f)
      ;;
      ;; cbs is a mutable vector matching CrestDialect::Callbacks slot order.
      ;; Each :keyword branch sets the exact slot index — no secondary
      ;; slot lookup needed at call time.
      (define (parse-clauses clauses-stx default-name)
        ;; ops and cbs are mutable state shared across the recursion.
        ;; loop only varies over the remaining syntax — no extra accumulators.
        (let ([ops '()]
              [cbs (make-vector 12 #f)])

          ;; Parse sub-clauses of a define-op — name already checked by caller.
          ;; Returns alist: ((operands . pairs) (attributes . pairs) (results . pairs))
          ;; where pairs = list of (name-stx type-stx).
          (define (parse-define-op sub-clauses-stx)
            (let ([operands   '()]
                  [attributes '()]
                  [results    '()])
              (let loop-sub ([stx sub-clauses-stx])
                (syntax-case stx (:summary :description
                                           :operands :attributes :results)
                  [(:summary     _ . rest)  (loop-sub #'rest)]
                  [(:description _ . rest)  (loop-sub #'rest)]
                  [(:operands    ((name type) ...) . rest)
                   (andmap (lambda (n) (identifier? n)) (syntax->list #'(name ...)))
                   (begin
                     (set! operands (syntax->datum #'((name type) ...)))
                     (loop-sub #'rest))]
                  [(:attributes  ((name type) ...) . rest)
                   (andmap (lambda (n) (identifier? n)) (syntax->list #'(name ...)))
                   (begin
                     (set! attributes (syntax->datum #'((name type) ...)))
                     (loop-sub #'rest))]
                  [(:results     ((name type) ...) . rest)
                   (andmap (lambda (n) (identifier? n)) (syntax->list #'(name ...)))
                   (begin
                     (set! results (syntax->datum #'((name type) ...)))
                     (loop-sub #'rest))]
                  [(bad . _)
                   (syntax-violation 'define-op
                                     "unknown clause — expected :operands, :attributes, :results, :summary, or :description"
                                     #'bad)]
                  [()
                   (list (cons 'operands   operands)
                         (cons 'attributes attributes)
                         (cons 'results    results))]))))


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
              ;; Documentation-only — same placeholder role as in define-op
              [(:summary     _ . rest) (loop #'rest)]
              [(:description _ . rest) (loop #'rest)]
              [((define-op op-name . op-sub) . rest)
               (identifier? #'op-name)
               (begin
                 ;; Parse sub-clauses and store structured result alongside name
                 (let ([parsed (parse-define-op #'op-sub)])
                   (set! ops (cons (cons #'op-name parsed) ops)))
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
               (list (cons 'name default-name)
                     (cons 'ops  (reverse ops))
                     (cons 'cbs  cbs))]))))

      (syntax-case stx ()
        [(_ dialect-id clause ...)
         (let* ([dialect-sym  (syntax->datum #'dialect-id)]
                [parsed       (parse-clauses #'(clause ...)
                                             (symbol->string dialect-sym))]
                [dialect-name (cdr (assq 'name parsed))]
                [op-clauses   (cdr (assq 'ops  parsed))]
                [extra-cbs    (cdr (assq 'cbs  parsed))]  ; (key-stx val-stx ...)
                [op-prefix    (string-append dialect-name ".")]

                ;; Helper: build a Scheme identifier in dialect-id's scope
                [make-id      (lambda (sfx)
                                (datum->syntax #'dialect-id (string->symbol sfx)))]
                [init-id      (make-id (string-append
                                        "%%" (symbol->string dialect-sym)
                                        ":initialize"))]
                [register-id  (make-id (string-append
                                        (symbol->string dialect-sym) ":register!"))]

                ;; op-clauses = list of (name-stx . ((operands . ...) (attributes . ...) (results . ...)))
                ;; Convert parsed alist back to plist datum for expand-op-defs.
                [op-names     (map (lambda (c)
                                     (string-append op-prefix
                                                    (symbol->string (syntax->datum (car c)))))
                                   op-clauses)]
                [all-op-defs  (apply append
                                     (map (lambda (c)
                                            (let* ([name-stx (car c)]
                                                   [parsed   (cdr c)]
                                                   [full-name (string-append op-prefix
                                                                             (symbol->string (syntax->datum name-stx)))]
                                                   ;; Reconstruct plist datum: (:operands (...) :attributes (...) ...)
                                                   [plist (apply append
                                                                 (map (lambda (entry)
                                                                        (if (null? (cdr entry)) '()
                                                                            (list (string->symbol
                                                                                   (string-append ":"
                                                                                                  (symbol->string (car entry))))
                                                                                  (cdr entry))))
                                                                      parsed))])
                                              (expand-op-defs #'dialect-id full-name plist)))
                                          op-clauses))]

                ;; Convert cbs vector to flat (quoted-key val ...) list.
                ;; Slot 0 (:initialize) is skipped — %%init is always used.
                ;; Slot N is included only when the user provided a callback.
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
                ;; extra-kv-list is already (quoted-key val ...) interleaved.
                [(extra-kv ...)    extra-kv-list])
             #'(begin
                 ;; Accessor and predicate definitions for each op
                 op-def ...

                 ;; Called by CrestDialect::initialize() in C++ when the dialect
                 ;; is first loaded. dialect-ptr is the CrestDialect* (uptr)
                 ;; passed by C++ as `this` — it arrives from the C++ side,
                 ;; not from any Scheme binding.
                 (define (%%init dialect-ptr)
                   (register-dynamic-op! dialect-ptr op-name-str) ...)

                 ;; extra-kv ... splices user dialect callbacks
                 ;; (':parse-type val ':print-type val ...) before :initialize
                 ;; so all 12 CrestDialect slots can be set from define-dialect.
                 (define (dialect:register! ctx)
                   (register-dialect! ctx dialect-name-str
                                      extra-kv ...
                                      ':initialize %%init)))))]))
    ))
