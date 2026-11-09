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
          (crest dialect expand interfaces)  ; generate-interface-registrations, dialect-cbs-with-interfaces
          (mlir IR Operation)
          (only (mlir Transforms InliningUtils) mlir::DialectInlinerInterface))

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

  ;; (reg-op dialect-ptr "toy.constant" (vector ...)) call for one op.
  (define (%%generate-register-op! ctx op-prefix op reg-op-stx)
    (let ([full-name    (%%id ctx ctx "." (op-parse-name op))]
          [name-str     (string-append op-prefix (%%id->str (op-parse-name op)))])
      (with-syntax ([reg-op reg-op-stx]
                    [op-name name-str]
                    [(cb ...) (%%op-cbs ctx full-name op)])
        #'(reg-op dialect-ptr op-name (vector cb ...)))))

  ;; ── Dialect types (define-type) ─────────────────────────────────────────────

  ;; (reg-type dialect-ptr "pair" (vector verify parse print)) for one type.
  (define (%%generate-register-type! ctx type reg-type-stx)
    (with-syntax ([reg-type  reg-type-stx]
                  [type-name (%%id->str (type-parse-name type))]
                  [(cb ...)  (map (lambda (cb) (or cb #'#f))
                                  (vector->list (type-parse-cbs type)))])
      #'(reg-type dialect-ptr type-name (vector cb ...))))

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
  (define (%%generate-dialect-callbacks ctx dialect-cbs ops stash-stx)
    (with-syntax ([dialect-value ctx]
                  [(cb ...) (dialect-cbs-with-interfaces ctx dialect-cbs ops)])
      (list #'(define dialect-value (crest-dialect-callback-entries cb ...)))))

  ;; Top-level: %%<dialect>:initialize + <dialect>:dialect-callbacks
  ;; <dialect>:register! is gone — use load-scheme-dialect! or
  ;; --crest-scheme-dialect= for standalone / pass-pipeline use respectively.
  ;; Interface concepts are registered at library-load time via toplevel-iface-calls.
  ;; Generate (define (%%<dialect>:<iface-name> method) (case method ...)) and
  ;; the registration call inside %%<dialect>:initialize for each dialect-level
  ;; interface entry.  Returns (values (list define-stx ...) (list init-call-stx ...)).
  (define (%%generate-dialect-iface-defs ctx dialect-ifaces)
    (let loop ([entries dialect-ifaces] [defs '()] [init-calls '()])
      (if (null? entries)
          (values (reverse defs) (reverse init-calls))
          (let* ([entry     (car entries)]
                 [iface-stx (interface-entry-name entry)]
                 [iface-str (%%id->str iface-stx)]
                 [_         (unless (string=? iface-str "mlir::DialectInlinerInterface")
                              (syntax-violation 'define-dialect
                                                "unsupported dialect-level interface"
                                                iface-stx))]
                 [methods   (interface-entry-methods entry)]
                 ;; %%<dialect>:<iface-name>  e.g. %%toy:mlir::DialectInlinerInterface
                 [proc-id   (%%id ctx "%%" ctx ":" iface-stx)])
            (with-syntax
                ([dispatch-proc proc-id]
                 [(method-clause ...)
                  (map (lambda (m)
                         (with-syntax
                             ([mname   (datum->syntax ctx (interface-method-name m))]
                              [formals (interface-method-formals m)]
                              [body    (interface-method-body m)])
                           #'((mname) (lambda formals . body))))
                       methods)])
              (loop
               (cdr entries)
               (cons #'(define (dispatch-proc method)
                         (case method
                           method-clause ...
                           (else #f)))
                     defs)
               ;; Registration call: inside %%<dialect>:initialize it has access to
               ;; dialect-ptr, so emit as a form to be spliced into the body.
               (cons #'(mlir::DialectInlinerInterface dialect-ptr dispatch-proc)
                     init-calls)))))))

  (define (generate-register-dialect ctx dialect-cbs ops reg-op-stx stash-stx
                                     . rest)
    ;; dialect-ifaces is an optional 6th argument (default empty list) so that
    ;; callers compiled before this change continue to work.
    (let ([dialect-ifaces (if (null? rest) '() (car rest))]
          [types          (if (or (null? rest) (null? (cdr rest))) '() (cadr rest))]
          [reg-type-stx   (if (or (null? rest) (null? (cdr rest))) #f (caddr rest))])
      (let ([op-prefix (string-append (%%id->str ctx) ".")])
        (let-values ([(iface-defs iface-calls)
                      (generate-interface-registrations ctx ops)]
                     [(diface-defs diface-init-calls)
                      (%%generate-dialect-iface-defs ctx dialect-ifaces)])
          (let ([base-defs
                 (with-syntax
                     ([%%toy.initialize (%%id ctx "%%" ctx ":initialize")]
                      [(type-reg ...)   (map (lambda (type)
                                               (%%generate-register-type! ctx type reg-type-stx))
                                             types)]
                      [(op-reg ...)     (map (lambda (op)
                                               (%%generate-register-op! ctx op-prefix op reg-op-stx))
                                             ops)]
                      [(diface-call ...) diface-init-calls]
                      [(user-init ...)   (let ([u (vector-ref dialect-cbs 0)])
                                           (if u (list #`(#,u dialect-ptr)) '()))])
                   (list
                    #'(define (%%toy.initialize dialect-ptr)
                        type-reg ... op-reg ... diface-call ... user-init ...)))]
                ;; stash-stx kept in signature for forward compat but unused now
                [dialect-cbs-defs (%%generate-dialect-callbacks ctx dialect-cbs ops stash-stx)]
                ;; Emit op iface-calls at library-load time so interface concepts are
                ;; registered when the library is imported.
                ;; Wrapped as a define to avoid "invalid context" in R6RS library bodies.
                [toplevel-iface-calls
                 (if (null? iface-calls)
                     '()
                     (with-syntax ([%%iface-marker (%%id ctx "%%" ctx "-iface-init")]
                                   [(iface-call ...) iface-calls])
                       (list #'(define %%iface-marker (begin iface-call ... #t)))))])
            (append diface-defs iface-defs base-defs dialect-cbs-defs toplevel-iface-calls))))))

  ) ;; end library (crest dialect expand)
