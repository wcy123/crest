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
          (crest dialect ffi)
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

  ;; Generate the auto interface-dispatch function from ops' :interfaces lists.
  ;; Returns a syntax object for the define, or #f if no op has :interfaces.
  (define (%%generate-interface-dispatch ctx ops)
    (let* ([op-prefix (string-append (%%id->str ctx) ".")]
           ;; Collect (full-op-name . providers) pairs for ops that declare interfaces
           [entries   (filter (lambda (pair) (not (null? (cdr pair))))
                              (map (lambda (op)
                                     (cons (string-append op-prefix (%%id->str (op-parse-name op)))
                                           (op-parse-interfaces op)))
                                   ops))])
      (if (null? entries)
          #f
          (with-syntax
              ([auto-fn   (%%id ctx "%%" ctx ":get-registered-interface-for-op-auto")]
               [getref    #'%mlir::OperationName::getStringRef]
               [(clause ...)
                (map (lambda (entry)
                       (let ([op-name-str (car entry)]
                             [providers   (cdr entry)])
                         (with-syntax
                             ([name-str op-name-str]
                              [(prov ...) providers])
                           #'[(string=? op-name name-str)
                              (let try ([ps (list prov ...)])
                                (if (null? ps) 0
                                    (let ([r ((car ps) iface-id)])
                                      (if (zero? r) (try (cdr ps)) r))))])))
                     entries)])
            #'(define (auto-fn iface-id op-name)
                (let ([op-name (getref op-name)])
                  (cond clause ... [else 0])))))))

  ;; Dialect callbacks vector with slot 0 wired to %%<dialect>:initialize,
  ;; and slot 11 combining auto-dispatch (from :interfaces) with user-provided.
  (define (%%dialect-cbs ctx dialect-cbs ops)
    (let* ([v            (list->vector (map (lambda (i) (or (vector-ref dialect-cbs i) #'#f))
                                            '(0 1 2 3 4 5 6 7 8 9 10 11)))]
           [auto-fn-stx  (%%id ctx "%%" ctx ":get-registered-interface-for-op-auto")]
           ;; Check the raw vector for user-provided slot 11 (before (or ... #'#f) wrapping).
           [user-iface   (vector-ref dialect-cbs 11)]
           [has-ifaces   (exists (lambda (op) (not (null? (op-parse-interfaces op)))) ops)])
      (vector-set! v 0 (%%id ctx "%%" ctx ":initialize"))
      (when has-ifaces
        (vector-set! v 11
                     (if user-iface
                         ;; auto first, user's callback as fallback
                         (with-syntax ([auto auto-fn-stx] [user user-iface])
                           #'(lambda (iface-id op-name)
                               (let ([r (auto iface-id op-name)])
                                 (if (zero? r) (user iface-id op-name) r))))
                         ;; auto only — no user callback
                         auto-fn-stx)))
      (vector->list v)))

  ;; (toy:register! ctx) — calls %crest::register-dialect! with all 12 callbacks.
  ;; reg-dialect-stx — syntax for %crest::register-dialect! from the macro's definition site.
  (define (%%generate-register! ctx dialect-cbs ops reg-dialect-stx)
    (with-syntax
        ([toy.register! (%%id ctx ctx ":register!")]
         [reg-dialect   reg-dialect-stx]
         [name-str      (%%id->str ctx)]
         [(cb ...)      (%%dialect-cbs ctx dialect-cbs ops)])
      #'(define (toy.register! ctx)
          (reg-dialect ctx name-str (vector cb ...)))))

  ;; Aggregates %%<dialect>:initialize, auto interface-dispatch, and
  ;; <dialect>:register! into a list of defines.
  (define (generate-register-dialect ctx dialect-cbs ops reg-op-stx reg-dialect-stx)
    (let* ([op-prefix   (string-append (%%id->str ctx) ".")]
           [auto-iface  (%%generate-interface-dispatch ctx ops)]
           [base-defs
            (with-syntax
                ([%%toy.initialize (%%id ctx "%%" ctx ":initialize")]
                 [(op-reg ...)     (map (lambda (op) (%%generate-register-op! ctx op-prefix op reg-op-stx)) ops)])
              (list
               #'(define (%%toy.initialize dialect-ptr) op-reg ...)
               (%%generate-register! ctx dialect-cbs ops reg-dialect-stx)))])
      (if auto-iface
          (cons auto-iface base-defs)
          base-defs)))
  )
