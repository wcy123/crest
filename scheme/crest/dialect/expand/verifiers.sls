;; Verifier code generators for define-dialect ops.
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp verify() methods.
(library (crest dialect expand verifiers)
  (export generate-op-verify-slot)
  (import (chezscheme)
          (crest dialect ast)
          (crest dialect expand utils)
          (crest pattern-dsl srcloc)
          (mlir IR Operation))

  ;; Single attribute check — returns a CHECK FORM (not a define).
  (define (%%gen-attr-check ctx op-stx field)
    (let* ([name-str  (%%id->str (attribute-field-name field))]
           [type-stx  (attribute-field-type field)]
           [type-str  (%%id->str type-stx)]
           [modifier  (attribute-field-modifier field)]
           [loc       (syntax->file+line+col (attribute-field-name field))]
           [loc-str   (if loc
                          (string-append " (declared at " (car loc) ":"
                                         (number->string (cadr loc)) ":"
                                         (number->string (caddr loc)) ")")
                          "")])
      (case modifier
        [(:required)
         (with-syntax ([op        op-stx]
                       [attr-name name-str]
                       [attr-type type-stx]
                       [err-absent (string-append "required attribute '" name-str
                                                  "' is missing" loc-str)]
                       [err-type   (string-append "type mismatch: (" type-str " "
                                                  name-str ") must be #t" loc-str)])
           #'(let ([%%v (mlir::Operation::getAttr op attr-name)])
               (and (or %%v    (begin (mlir::Operation::emitError op err-absent) #f))
                    (or (attr-type %%v) (begin (mlir::Operation::emitError op err-type) #f)))))]
        [(:optional)
         (with-syntax ([op        op-stx]
                       [attr-name name-str]
                       [attr-type type-stx]
                       [err-msg   (string-append "type mismatch: (" type-str " "
                                                 name-str ") must be #t when present"
                                                 loc-str)])
           #'(let ([%%v (mlir::Operation::getAttr op attr-name)])
               (or (not %%v)
                   (attr-type %%v)
                   (begin (mlir::Operation::emitError op err-msg) #f))))])))

  ;; Check form for one result — verifies the result satisfies its type predicate.
  (define (%%gen-result-check ctx op-stx field index)
    (let* ([name-str (symbol->string (car field))]
           [type-stx (datum->syntax ctx (cadr field))]
           [type-str (symbol->string (cadr field))]
           [err-msg  (string-append "type mismatch: (" type-str " "
                                    name-str ") must be #t")])
      (with-syntax ([op          op-stx]
                    [result-type type-stx]
                    [result-idx  index]
                    [err         err-msg])
        #'(or (result-type (mlir::Operation::getResult op result-idx))
              (begin (mlir::Operation::emitError op err) #f)))))

  ;; All check forms for one op — attributes + results + operands (stub).
  ;; op-stx is the fresh lambda parameter threaded from generate-op-verify-slot.
  (define (%%generate-verify-forms ctx op-stx op-record)
    (append
     (map (lambda (f) (%%gen-attr-check ctx op-stx f)) (op-parse-attributes op-record))
     (let loop ([fields (op-parse-results op-record)] [idx 0])
       (if (null? fields) '()
           (cons (%%gen-result-check ctx op-stx (car fields) idx)
                 (loop (cdr fields) (+ idx 1)))))))

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
