;; Expand-phase helpers for op code generation.
;; Imported at (for ... expand) by (crest dialect).
(library (crest dialect expand)
  (export generate-all-op-defs
          generate-type-defs
          generate-register-dialect)
  (import (chezscheme)
          (rime loop)
          (crest dialect ast)
          (crest dialect expand utils)
          (crest dialect expand verifiers)
          (crest dialect callbacks)          ; crest-dialect-callback-entries
          (crest dialect expand interfaces)  ; dialect-cbs-with-interfaces
          (mlir IR Operation))

  ;; ── Accessor generators ────────────────────────────────────────────────────

  (define (generate-isa ctx full-name)
    (with-syntax ([isa?   (%%id ctx full-name "?")]
                  [name-s (%%id->str full-name)])
      #'(define (isa? op)
          (string=? (mlir::Operation::getName op) name-s))))

  (define (generate-operand-accessor ctx full-name field index)
    (with-syntax ([id  (%%id ctx full-name ":" (operand-field-name field))]
                  [idx index])
      #'(define (id op) (mlir::Operation::getOperand op idx))))

  (define (generate-attribute-accessor ctx full-name field)
    (with-syntax ([id    (%%id ctx full-name ":" (attribute-field-name field))]
                  [aname (%%id->str (attribute-field-name field))])
      #'(define (id op) (mlir::Operation::getAttr op aname))))

  (define (generate-result-accessor ctx full-name field index)
    (with-syntax ([id  (%%id ctx full-name ":" (result-field-name field))]
                  [idx index])
      #'(define (id op) (mlir::Operation::getResult op idx))))

  ;; All accessor defines for one op (isa?, operand, attr, result accessors).
  (define (generate-op-defs ctx op)
    (let ([full-name (%%id ctx ctx "." (op-parse-name op))])
      (append
       (list (generate-isa ctx full-name))
       (loop :for f :in (op-parse-operands  op) :for i :from 0
             :collect (generate-operand-accessor  ctx full-name f i))
       (loop :for f :in (op-parse-attributes op)
             :collect (generate-attribute-accessor ctx full-name f))
       (loop :for f :in (op-parse-results    op) :for i :from 0
             :collect (generate-result-accessor    ctx full-name f i)))))

  (define (generate-all-op-defs ctx ops)
    (apply append (map (lambda (op) (generate-op-defs ctx op)) ops)))

  ;; ── Registration generators ────────────────────────────────────────────────

  ;; 8-slot op-callbacks vector (verify inlined, rest forwarded verbatim; slot 7 is the
  ;; list of trait names, '() when there are none).
  (define (%%op-cbs ctx full-name op)
    (let* ([cbs (op-parse-op-cbs op)]
           [v   (list->vector (map (lambda (i) (or (vector-ref cbs i) (if (= i 7) #''() #'#f)))
                                   '(0 1 2 3 4 5 6 7)))])
      (vector-set! v 0 (generate-op-verify-slot ctx full-name op (vector-ref cbs 0)))
      (vector->list v)))

  ;; The name of the library-level variable that holds the entry points of the callbacks of an op
  ;; (or of a type): its foreign-callables are made once, when the library is loaded, and every
  ;; context that loads the dialect registers the op with this same vector.
  (define (%%op-callbacks-id ctx op)
    (%%id ctx "%%" ctx "." (op-parse-name op) ":op-callbacks"))

  (define (%%type-callbacks-id ctx type)
    (%%id ctx "%%" ctx "." (type-parse-name type) ":type-callbacks"))

  ;; (define %%toy.constant:op-callbacks (crest-op-callback-entries "toy.constant" cb ...)) for one op.
  (define (%%generate-op-callbacks-def ctx op-prefix op)
    (let ([full-name    (%%id ctx ctx "." (op-parse-name op))]
          [name-str     (string-append op-prefix (%%id->str (op-parse-name op)))])
      (with-syntax ([callbacks (%%op-callbacks-id ctx op)]
                    [op-name name-str]
                    [(cb ...) (%%op-cbs ctx full-name op)])
        #'(define callbacks (crest-op-callback-entries op-name cb ...)))))

  ;; The name of the library-level variable that holds the (TypeID . dispatcher) pairs of the
  ;; :interfaces entries of an op. Each entry is a use of a macro of the library of its interface, which
  ;; makes the C functions of the clauses: they are made once, when the library is loaded.
  (define (%%interfaces-id ctx op)
    (%%id ctx "%%" ctx "." (op-parse-name op) ":interfaces"))

  ;; (define %%toy.add:interfaces (list (mlir::InferTypeOpInterface clause ...) ...)) for one op.
  (define (%%generate-interfaces-def ctx op)
    (with-syntax ([interfaces (%%interfaces-id ctx op)]
                  [(entry ...) (op-parse-interfaces op)])
      #'(define interfaces (list entry ...))))

  ;; (reg-op dialect-ptr "toy.constant" %%toy.constant:op-callbacks %%toy.constant:interfaces) call
  ;; for one op.
  (define (%%generate-register-op! ctx op-prefix op reg-op-stx)
    (let ([name-str (string-append op-prefix (%%id->str (op-parse-name op)))])
      (with-syntax ([reg-op reg-op-stx]
                    [op-name name-str]
                    [callbacks (%%op-callbacks-id ctx op)]
                    [interfaces (%%interfaces-id ctx op)])
        #'(reg-op dialect-ptr op-name callbacks interfaces))))

  ;; ── Dialect types (define-type) ─────────────────────────────────────────────

  ;; (define %%toy.pair:type-callbacks (crest-type-callback-entries verify parse print)) for one type.
  (define (%%generate-type-callbacks-def ctx type)
    (with-syntax ([callbacks (%%type-callbacks-id ctx type)]
                  [(cb ...)  (map (lambda (cb) (or cb #'#f))
                                  (vector->list (type-parse-cbs type)))])
      #'(define callbacks (crest-type-callback-entries cb ...))))

  ;; (reg-type dialect-ptr "pair" %%toy.pair:type-callbacks) for one type.
  (define (%%generate-register-type! ctx type reg-type-stx)
    (with-syntax ([reg-type  reg-type-stx]
                  [type-name (%%id->str (type-parse-name type))]
                  [callbacks (%%type-callbacks-id ctx type)])
      #'(reg-type dialect-ptr type-name callbacks)))

  ;; <dialect>.<type>? / <dialect>.<type> / <dialect>.<type>-params for each type:
  ;;   (toy.struct? type)            #t when type is that dialect type
  ;;   (toy.struct ctx params)       the type with these attribute parameters (0 if it does not verify)
  ;;   (toy.struct-params type)      the list of its attribute parameters
  (define (generate-type-defs ctx types get-stx isa-stx params-stx)
    (apply append
           (map (lambda (type)
                  (let ([full-name (%%id ctx ctx "." (type-parse-name type))])
                    (with-syntax ([isa?       (%%id ctx full-name "?")]
                                  [make       full-name]
                                  [params-of  (%%id ctx full-name "-params")]
                                  [dialect-s  (%%id->str ctx)]
                                  [type-s     (%%id->str (type-parse-name type))]
                                  [get-fn     get-stx]
                                  [isa-fn     isa-stx]
                                  [params-fn  params-stx])
                      (list #'(define (isa? type) (eqv? 1 (isa-fn dialect-s type-s type)))
                            #'(define (make ctx params) (get-fn dialect-s type-s params ctx))
                            #'(define (params-of type) (params-fn type))))))
                types)))

  ;; Generates (define testd (crest-dialect-callback-entries cb ...)) at library-load time: it
  ;; binds the dialect name itself to the vector of the entry points of the callbacks.  Uses ctx
  ;; (the call-site identifier) so the binding has the same scope as the user's (export testd),
  ;; making it accessible from C++ via Stop_level_value(Sstring_to_symbol("testd")) after import.
  (define (%%generate-dialect-callbacks ctx dialect-cbs ops)
    (with-syntax ([dialect-value ctx]
                  [(cb ...) (dialect-cbs-with-interfaces ctx dialect-cbs ops)])
      (list #'(define dialect-value (crest-dialect-callback-entries cb ...)))))

  ;; The name of the library-level variable that holds the (TypeID . dispatcher) pairs of the
  ;; :interfaces entries of the dialect itself (an op's are in %%<dialect>.<op>:interfaces). Each
  ;; entry is a use of a macro of the library of its interface, which makes the C functions of the
  ;; clauses: they are made once, when the library is loaded. The list is slot 11 of the callbacks
  ;; vector, and C++ installs each interface in the dialect when a context loads it
  ;; (lib/Crest/Dialect.cpp).
  (define (%%dialect-interfaces-id ctx)
    (%%id ctx "%%" ctx ":interfaces"))

  ;; (define %%toy:interfaces (list (mlir::DialectInlinerInterface clause ...) ...))
  (define (%%generate-dialect-interfaces-def ctx dialect-ifaces)
    (with-syntax ([interfaces (%%dialect-interfaces-id ctx)]
                  [(entry ...) dialect-ifaces])
      #'(define interfaces (list entry ...))))

  (define (generate-register-dialect ctx dialect-cbs ops reg-op-stx dialect-ifaces types reg-type-stx)
    (let ()
      (let ([op-prefix (string-append (%%id->str ctx) ".")])
        (let ()
          (let ([base-defs
                 (with-syntax
                     ([%%toy.initialize (%%id ctx "%%" ctx ":initialize")]
                      [(type-reg ...)   (map (lambda (type)
                                               (%%generate-register-type! ctx type reg-type-stx))
                                             types)]
                      [(op-reg ...)     (map (lambda (op)
                                               (%%generate-register-op! ctx op-prefix op reg-op-stx))
                                             ops)]
                      [(user-init ...)   (let ([u (vector-ref dialect-cbs 0)])
                                           (if u (list #`(#,u dialect-ptr)) '()))])
                   (list
                    #'(define (%%toy.initialize dialect-ptr)
                        type-reg ... op-reg ... user-init ...)))]
                [dialect-cbs-defs (%%generate-dialect-callbacks ctx dialect-cbs ops)])
            (append (list (%%generate-dialect-interfaces-def ctx dialect-ifaces))
                    (map (lambda (op) (%%generate-interfaces-def ctx op)) ops)
                    (map (lambda (op) (%%generate-op-callbacks-def ctx op-prefix op)) ops)
                    (map (lambda (type) (%%generate-type-callbacks-def ctx type)) types)
                    base-defs dialect-cbs-defs))))))

  ) ;; end library (crest dialect expand)
