;; Verifier code generators for define-dialect ops.
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp verify() methods.
(library (crest dialect expand verifiers)
  (export generate-op-verify-slot)
  (import (chezscheme)
          (rime loop)
          (crest dialect ast)
          (crest dialect expand utils)
          (crest pattern-dsl srcloc)
          (mlir IR Operation)
          (only (mlir IR Value) mlir::Value::getType)
          (mlir IR BuiltinAttributes))

  ;; Single attribute check — returns a CHECK FORM (not a define).
  (define (%%gen-attr-check ctx op-stx field)
    (let* ([name-stx  (attribute-field-name field)]
           [name-str  (%%id->str name-stx)]
           [type-stx  (attribute-field-type field)]
           [type-str  (%%id->str type-stx)]
           [modifier  (attribute-field-modifier field)])
      (case modifier
        [(:required)
         (with-syntax ([op        op-stx]
                       [attr-name name-str]
                       [attr-type type-stx]
                       [err-absent (make-error-message name-stx "required attribute '" name-str "' is missing")]
                       [err-type   (make-error-message name-stx "type mismatch: (" type-str " " name-str ") must be #t")])
           #'(let ([%%v (mlir::Operation::getAttr op attr-name)])
               (and (or %%v    (begin (mlir::Operation::emitError op err-absent) #f))
                    (or (attr-type %%v) (begin (mlir::Operation::emitError op err-type) #f)))))]
        [(:optional)
         (with-syntax ([op        op-stx]
                       [attr-name name-str]
                       [attr-type type-stx]
                       [err-msg   (make-error-message name-stx "type mismatch: (" type-str " " name-str ") must be #t when present")])
           #'(let ([%%v (mlir::Operation::getAttr op attr-name)])
               (or (not %%v)
                   (attr-type %%v)
                   (begin (mlir::Operation::emitError op err-msg) #f))))])))

  ;; Check form for one result — verifies the result satisfies its type predicate.
  (define (%%gen-result-check ctx op-stx field index)
    (let* ([name-stx  (result-field-name field)]
           [name-str  (%%id->str name-stx)]
           [type-stx  (result-field-type field)]
           [type-str  (%%id->str type-stx)]
           [err-msg   (make-error-message name-stx "type mismatch: (" type-str " " name-str ") must be #t")])
      (with-syntax ([op          op-stx]
                    [result-type type-stx]
                    [result-idx  index]
                    [err         err-msg])
        ;; Type predicates take a mlir::Type*, not a Value*.
        ;; Wrap the result Value with mlir::Value::getType before checking.
        #'(or (result-type (mlir::Value::getType (mlir::Operation::getResult op result-idx)))
              (begin (mlir::Operation::emitError op err) #f)))))

  ;; Check that the number of results matches the declaration.
  (define (%%gen-result-count-check ctx op-stx op-record)
    (let* ([results  (op-parse-results op-record)]
           [expected (length results)]
           ;; Use first result's name as location; fall back to op name.
           [loc-stx  (if (null? results)
                         (op-parse-name op-record)
                         (result-field-name (car results)))]
           [err-msg  (make-error-message loc-stx "expected " expected " result(s)")])
      (with-syntax ([op    op-stx]
                    [count expected]
                    [err   err-msg])
        #'(or (= (mlir::Operation::getNumResults op) count)
              (begin (mlir::Operation::emitError op err) #f)))))

  ;; -------------------------------------------------------------------------
  ;; Operand verification
  ;; -------------------------------------------------------------------------

  (define (%%has-flex-operands? op-record)
    (not (for-all (lambda (f) (eq? (operand-field-modifier f) ':required))
                  (op-parse-operands op-record))))

  ;; Check form for one :required operand.
  (define (%%gen-required-operand-check ctx op-stx field idx)
    (let* ([name-stx  (operand-field-name field)]
           [name-str  (%%id->str name-stx)]
           [type-stx  (operand-field-type field)]
           [type-str  (%%id->str type-stx)])
      (with-syntax ([op           op-stx]
                    [operand-type type-stx]
                    [operand-idx  idx]
                    [err          (make-error-message name-stx "type mismatch: (" type-str " " name-str ") must be #t")])
        #'(or (operand-type (mlir::Operation::getOperand op operand-idx))
              (begin (mlir::Operation::emitError op err) #f)))))

  ;; All-required operands: count check then per-operand type checks.
  (define (%%generate-required-operand-checks ctx op-stx operands)
    (let ([count (length operands)])
      (cons
       (with-syntax ([op op-stx] [n count]
                     [err (make-error-message (operand-field-name (car operands))
                                              "expected " count " operand(s)")])
         #'(or (= (mlir::Operation::getNumOperands op) n)
               (begin (mlir::Operation::emitError op err) #f)))
       (loop :for field :in operands :for idx :from 0
             :collect (%%gen-required-operand-check ctx op-stx field idx)))))

  ;; Check form for one segment — dispatches on modifier.
  (define (%%gen-segment-check ctx op-stx field size-id start-id)
    (let* ([name-stx  (operand-field-name field)]
           [name-str  (%%id->str name-stx)]
           [type-stx  (operand-field-type field)]
           [type-str  (%%id->str type-stx)]
           [modifier  (operand-field-modifier field)])
      (case modifier
        [(:required)
         (with-syntax ([op   op-stx] [type type-stx] [size size-id] [start start-id]
                       [err-sz (make-error-message name-stx "required operand '" name-str "' must have exactly 1 value")]
                       [err-ty (make-error-message name-stx "type mismatch: (" type-str " " name-str ") must be #t")])
           #'(and (or (= size 1) (begin (mlir::Operation::emitError op err-sz) #f))
                  (or (type (mlir::Operation::getOperand op start))
                      (begin (mlir::Operation::emitError op err-ty) #f))))]
        [(:optional)
         (with-syntax ([op   op-stx] [type type-stx] [size size-id] [start start-id]
                       [err-sz (make-error-message name-stx "optional operand '" name-str "' must have 0 or 1 value")]
                       [err-ty (make-error-message name-stx "type mismatch: (" type-str " " name-str ") must be #t when present")])
           #'(and (or (or (= size 0) (= size 1)) (begin (mlir::Operation::emitError op err-sz) #f))
                  (or (= size 0)
                      (type (mlir::Operation::getOperand op start))
                      (begin (mlir::Operation::emitError op err-ty) #f))))]
        [(:variadic)
         (with-syntax ([op   op-stx] [type type-stx] [size size-id] [start start-id]
                       [err-ty (make-error-message name-stx "type mismatch: (" type-str " " name-str ") must be #t")])
           #'(loop :for %%i :from 0 :below size
                   :break #f
                   :unless (or (type (mlir::Operation::getOperand op (+ start %%i)))
                               (begin (mlir::Operation::emitError op err-ty) #f))
                   :finally #t))])))

  ;; Flex operands: check operandSegmentSizes, then per-segment checks.
  (define (%%generate-flex-operand-checks ctx op-stx operands)
    (let* ([n          (length operands)]
           [indices    (iota n)]
           [size-ids   (map (lambda (i) (%%id ctx "%%" "size" (number->string i))) indices)]
           [start-ids  (map (lambda (i) (%%id ctx "%%" "start" (number->string i))) indices)]
           [size-bindings
            (map (lambda (size-id i)
                   (with-syntax ([s size-id] [k i])
                     #'[s (vector-ref %%segs k)]))
                 size-ids indices)]
           [start-bindings
            (let loop ([i 0] [prev #'0])
              (if (= i n) '()
                  (cons (with-syntax ([st (list-ref start-ids i)] [p prev])
                          #'[st p])
                        (loop (+ i 1)
                              (with-syntax ([st (list-ref start-ids i)]
                                            [sz (list-ref size-ids i)])
                                #'(+ st sz))))))]
           [segment-checks
            (map (lambda (field size-id start-id)
                   (%%gen-segment-check ctx op-stx field size-id start-id))
                 operands size-ids start-ids)])
      (list
       (with-syntax ([op       op-stx]
                     [n-segs   n]
                     [(sb ...) size-bindings]
                     [(stb ...) start-bindings]
                     [(chk ...) segment-checks]
                     [err-attr (make-error-message #f "operandSegmentSizes is missing or not a DenseI32ArrayAttr")]
                     [err-cnt  (make-error-message #f "operandSegmentSizes must have " n " entries")])
         #'(let ([%%seg-attr (mlir::Operation::getAttr op "operandSegmentSizes")])
             (and
              (or (and %%seg-attr (mlir::isa<DenseI32ArrayAttr> %%seg-attr))
                  (begin (mlir::Operation::emitError op err-attr) #f))
              (let ([%%segs (mlir::DenseI32ArrayAttr::toVector %%seg-attr)])
                (and
                 (or (= (vector-length %%segs) n-segs)
                     (begin (mlir::Operation::emitError op err-cnt) #f))
                 (let* (sb ... stb ...)
                   (and chk ...))))))))))

  ;; Entry point: dispatch to the right operand check strategy.
  (define (%%generate-operand-verify-forms ctx op-stx op-record)
    (let ([operands (op-parse-operands op-record)])
      (if (null? operands)
          '()
          (if (%%has-flex-operands? op-record)
              (%%generate-flex-operand-checks ctx op-stx operands)
              (%%generate-required-operand-checks ctx op-stx operands)))))

  ;; All check forms for one op:
  ;;   1. result count + result types
  ;;   2. operand count/segment + operand types
  ;;   3. attribute presence + attribute types
  (define (%%generate-verify-forms ctx op-stx op-record)
    (append
     (list (%%gen-result-count-check ctx op-stx op-record))
     (loop :for field :in (op-parse-results op-record) :for idx :from 0
           :collect (%%gen-result-check ctx op-stx field idx))
     (%%generate-operand-verify-forms ctx op-stx op-record)
     (map (lambda (f) (%%gen-attr-check ctx op-stx f)) (op-parse-attributes op-record))))

  ;; Returns (values verifier-define slot-stx).
  ;; verifier-define — (define (%%<op>:verify op) ...) syntax.
  ;; slot-stx        — syntax for slot 0: the verifier ref, or composed with user's.
  ;; With no attributes, (and) = #t — the verifier trivially passes.
  ;; Returns the slot-0 callback syntax — an anonymous lambda with inlined checks.
  ;; No separate %%<op>:verify define needed: checks are always inlined.
  (define (generate-op-verify-slot ctx full-name op-record user-verifier)
    (let* ([fresh-op (car (generate-temporaries '(op)))]
           [checks   (%%generate-verify-forms ctx fresh-op op-record)])
      (with-syntax ([op         fresh-op]
                    [(check ...) checks]
                    [(user ...)  (if user-verifier (list user-verifier) '())])
        #'(lambda (op) (and check ... (user op) ...)))))
  )
