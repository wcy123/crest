;; Expand-phase helpers for op code generation.
;; Imported at (for ... expand) by (crest dialect).
(library (crest dialect expand)
  (export generate-all-op-defs
          generate-register-dialect)
  (import (chezscheme)
          (rime loop)
          (crest dialect ast)
          (crest dialect expand utils)
          (crest dialect expand verifiers)
          (crest dialect expand interfaces)  ; generate-interface-registrations, dialect-cbs-with-interfaces
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

  ;; 7-slot op-callbacks vector (verify inlined, rest forwarded verbatim).
  (define (%%op-cbs ctx full-name op)
    (let* ([cbs (op-parse-op-cbs op)]
           [v   (list->vector (map (lambda (i) (or (vector-ref cbs i) #'#f))
                                   '(0 1 2 3 4 5 6)))])
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

  ;; Generates at library-load time:
  ;;   (define <dialect>:dialect-callbacks (vector cb ...))
  ;; Generates (define testd (vector ...)) — binds the dialect name itself to
  ;; the callbacks vector.  Uses ctx (the call-site identifier) so the binding
  ;; has the same scope as the user's (export testd), making it accessible from
  ;; C++ via Stop_level_value(Sstring_to_symbol("testd")) after import.
  (define (%%generate-dialect-callbacks ctx dialect-cbs ops stash-stx)
    (with-syntax ([dialect-value ctx]
                  [(cb ...) (dialect-cbs-with-interfaces ctx dialect-cbs ops)])
      (list #'(define dialect-value (vector cb ...)))))

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
                 [methods   (interface-entry-methods entry)]
                 ;; %%<dialect>:<iface-name>  e.g. %%toy:mlir::DialectInlinerInterface
                 [proc-id   (%%id ctx "%%" ctx ":" iface-stx)])
            (with-syntax
                ([dispatch-proc proc-id]
                 [iface-sym     iface-str]
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
               (cons #'((foreign-procedure iface-sym (uptr scheme-object) void)
                        dialect-ptr dispatch-proc)
                     init-calls)))))))

  (define (generate-register-dialect ctx dialect-cbs ops reg-op-stx stash-stx
                                     . rest)
    ;; dialect-ifaces is an optional 6th argument (default empty list) so that
    ;; callers compiled before this change continue to work.
    (let ([dialect-ifaces (if (null? rest) '() (car rest))])
      (let ([op-prefix (string-append (%%id->str ctx) ".")])
        (let-values ([(iface-defs iface-calls)
                      (generate-interface-registrations ctx ops)]
                     [(diface-defs diface-init-calls)
                      (%%generate-dialect-iface-defs ctx dialect-ifaces)])
          (let ([base-defs
                 (with-syntax
                     ([%%toy.initialize (%%id ctx "%%" ctx ":initialize")]
                      [(op-reg ...)     (map (lambda (op)
                                               (%%generate-register-op! ctx op-prefix op reg-op-stx))
                                             ops)]
                      [(diface-call ...) diface-init-calls])
                   (list
                    #'(define (%%toy.initialize dialect-ptr) op-reg ... diface-call ...)))]
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
