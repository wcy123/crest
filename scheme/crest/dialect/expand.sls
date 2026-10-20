;; Expand-phase helpers for op code generation.
;; Imported at (for ... expand) by (crest dialect).
(library (crest dialect expand)
  (export generate-isa
          generate-operand-accessor
          generate-attribute-accessor
          generate-result-accessor
          generate-verifier
          generate-op-defs
          generate-all-op-defs
          generate-register-dialect)
  (import (chezscheme)
          (rime loop)
          (crest dialect ast)
          (crest dialect expand utils)
          (crest dialect expand verifiers)
          (mlir IR Operation))

  ;; (toy.constant? op) → bool
  (define (generate-isa ctx full-name)
    (with-syntax ([isa?   (%%id ctx full-name "?")]
                  [name-s (%%id->str full-name)])
      #'(define (isa? op)
          (string=? (mlir::Operation::getName op) name-s))))

  ;; (toy.constant:input op) → mlir::Value  for operand at index
  (define (generate-operand-accessor ctx full-name field index)
    (with-syntax ([id  (%%id ctx full-name ":" (operand-field-name field))]
                  [idx index])
      #'(define (id op)
          (mlir::Operation::getOperand op idx))))

  ;; (toy.constant:value op) → mlir::Attribute  for named attribute
  (define (generate-attribute-accessor ctx full-name field)
    (with-syntax ([id    (%%id ctx full-name ":" (attribute-field-name field))]
                  [aname (%%id->str (attribute-field-name field))])
      #'(define (id op)
          (mlir::Operation::getAttr op aname))))

  ;; (toy.constant:output op) → mlir::Value  for result at index
  (define (generate-result-accessor ctx full-name field index)
    (with-syntax ([id  (%%id ctx full-name ":" (car field))]
                  [idx index])
      #'(define (id op)
          (mlir::Operation::getResult op idx))))

  ;; All definitions for one op.
  (define (generate-op-defs ctx op)
    (let ([full-name (%%id ctx ctx "." (op-parse-name op))])
      (append
       (list (generate-isa ctx full-name))
       (loop :for field :in (op-parse-operands  op) :for idx :from 0
             :collect (generate-operand-accessor  ctx full-name field idx))
       (loop :for field :in (op-parse-attributes op)
             :collect (generate-attribute-accessor ctx full-name field))
       (loop :for field :in (op-parse-results    op) :for idx :from 0
             :collect (generate-result-accessor    ctx full-name field idx))
       (generate-verifier ctx full-name op))))

  ;; All op definitions for a dialect — flattened list of syntax objects.
  (define (generate-all-op-defs ctx ops)
    (apply append (map (lambda (op) (generate-op-defs ctx op)) ops)))

  ;; (toy:register! ctx) — registers the dialect + its %%initialize callback.
  ;; ops — list of op-parse records; each op name is registered in %%<dialect>:initialize.
  (define (generate-register-dialect ctx cbs ops)
    (let* ([op-prefix  (string-append (%%id->str ctx) ".")]
           [op-names   (map (lambda (op)
                              (string-append op-prefix (%%id->str (op-parse-name op))))
                            ops)]
           ;; Slot 0 always points to the generated init; override any #f.
           [cb-stxs    (let ([v (list->vector
                                 (map (lambda (i) (or (vector-ref cbs i) #'#f))
                                      '(0 1 2 3 4 5 6 7 8 9 10 11)))])
                         (vector-set! v 0 (%%id ctx "%%" ctx ":initialize"))
                         (vector->list v))])
      (with-syntax
          ([init!            (%%id ctx "%%" ctx ":initialize")]
           [register!        (%%id ctx ctx ":register!")]
           [ffi-fn           (%%id ctx "%crest::register-dialect!")]
           [name-str         (%%id->str ctx)]
           [(op-name-str ...) op-names]
           [(cb ...)          cb-stxs])
        ;; Return both defines as a list — the caller splices them into begin.
        (list
         #'(define (init! dialect-ptr)
             (register-dynamic-op! dialect-ptr op-name-str) ...)
         #'(define (register! ctx)
             (ffi-fn ctx name-str (vector cb ...)))))))
  )
