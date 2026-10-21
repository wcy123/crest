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
    (with-syntax ([id  (%%id ctx full-name ":" (result-field-name field))]
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
             :collect (generate-result-accessor    ctx full-name field idx)))))

  ;; All op definitions for a dialect — flattened list of syntax objects.
  (define (generate-all-op-defs ctx ops)
    (apply append (map (lambda (op) (generate-op-defs ctx op)) ops)))

  ;; Build the 7-slot op-callbacks vector.
  (define (%%op-cbs ctx full-name op)
    (let* ([op-cbs (op-parse-op-cbs op)]
           [v      (list->vector (map (lambda (i) (or (vector-ref op-cbs i) #'#f))
                                      '(0 1 2 3 4 5 6)))])
      (vector-set! v 0 (generate-op-verify-slot ctx full-name op (vector-ref op-cbs 0)))
      (vector->list v)))

  ;; Register call syntax for one op — passes cbs vector directly to C FFI.
  ;; reg-op-stx — syntax for %crest::register-dynamic-op! from the macro's definition site.
  (define (%%generate-register-op! ctx op-prefix op reg-op-stx)
    (let* ([full-name (%%id ctx ctx "." (op-parse-name op))]
           [name-str  (string-append op-prefix (%%id->str (op-parse-name op)))]
           [op-callbacks (%%op-cbs ctx full-name op)])
      (with-syntax ([reg-op reg-op-stx]
                    [op-name name-str] [(op-callbacks ...) op-callbacks])
        #'(reg-op dialect-ptr op-name (vector op-callbacks ...)))))

  ;; Dialect callbacks vector with slot 0 wired to %%<dialect>:initialize.
  (define (%%dialect-cbs ctx dialect-cbs)
    (let ([v (list->vector (map (lambda (i) (or (vector-ref dialect-cbs i) #'#f))
                                '(0 1 2 3 4 5 6 7 8 9 10 11)))])
      (vector-set! v 0 (%%id ctx "%%" ctx ":initialize"))
      (vector->list v)))

  ;; (toy:register! ctx) — calls %crest::register-dialect! with all 12 callbacks.
  ;; reg-dialect-stx — syntax for %crest::register-dialect! from the macro's definition site.
  (define (%%generate-register! ctx dialect-cbs reg-dialect-stx)
    (with-syntax
        ([toy.register! (%%id ctx ctx ":register!")]
         [reg-dialect   reg-dialect-stx]
         [name-str      (%%id->str ctx)]
         [(cb ...)      (%%dialect-cbs ctx dialect-cbs)])
      #'(define (toy.register! ctx)
          (reg-dialect ctx name-str (vector cb ...)))))

  ;; Aggregates %%<dialect>:initialize and <dialect>:register! into a list of defines.
  ;; reg-op-stx / reg-dialect-stx — syntax refs to FFI fns from the macro's definition site,
  ;; passed in so the generated identifiers carry the correct (crest dialect ffi) scope.
  (define (generate-register-dialect ctx dialect-cbs ops reg-op-stx reg-dialect-stx)
    (let ([op-prefix (string-append (%%id->str ctx) ".")])
      (with-syntax
          ([%%toy.initialize (%%id ctx "%%" ctx ":initialize")]
           [(op-reg ...)     (map (lambda (op) (%%generate-register-op! ctx op-prefix op reg-op-stx)) ops)])
        (list
         #'(define (%%toy.initialize dialect-ptr) op-reg ...)
         (%%generate-register! ctx dialect-cbs reg-dialect-stx)))))
  )
