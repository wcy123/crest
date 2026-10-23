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
          (crest dialect expand interfaces)
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

  ;; (toy:register! ctx) form — registers the dialect with all 12 callbacks.
  (define (%%generate-register! ctx dialect-cbs ops reg-dialect-stx)
    (with-syntax ([toy.register! (%%id ctx ctx ":register!")]
                  [reg-dialect   reg-dialect-stx]
                  [name-str      (%%id->str ctx)]
                  [(cb ...)      (dialect-cbs-with-interfaces ctx dialect-cbs ops)])
      #'(define (toy.register! ctx)
          (reg-dialect ctx name-str (vector cb ...)))))

  ;; Top-level: %%<dialect>:initialize + optional interface dispatch + <dialect>:register!
  (define (generate-register-dialect ctx dialect-cbs ops reg-op-stx reg-dialect-stx)
    (let ([op-prefix  (string-append (%%id->str ctx) ".")]
          [auto-iface (generate-interface-dispatch ctx ops)])
      (let ([base-defs
             (with-syntax
                 ([%%toy.initialize (%%id ctx "%%" ctx ":initialize")]
                  [(op-reg ...)     (map (lambda (op)
                                           (%%generate-register-op! ctx op-prefix op reg-op-stx))
                                         ops)])
               (list
                #'(define (%%toy.initialize dialect-ptr) op-reg ...)
                (%%generate-register! ctx dialect-cbs ops reg-dialect-stx)))])
        (if auto-iface (cons auto-iface base-defs) base-defs))))

  ) ;; end library (crest dialect expand)
