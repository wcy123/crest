;; Verifier code generators for define-dialect ops.
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp verify() methods.
(library (crest dialect expand verifiers)
  (export generate-verifier)
  (import (chezscheme)
          (crest dialect ast)
          (crest dialect expand utils)
          (crest pattern-dsl srcloc)
          (mlir IR Operation))

  ;; Generate a single attribute check with diagnostics on failure.
  ;; Attribute name, type name, and declaration site are compile-time constants.
  (define (%%gen-attr-check ctx field)
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
         (with-syntax ([attr-name  name-str]
                       [attr-type  type-stx]
                       [err-absent (string-append "required attribute '" name-str
                                                  "' is missing" loc-str)]
                       [err-type   (string-append "type mismatch: (" type-str " "
                                                  name-str ") must be #t" loc-str)])
           ;; Two distinct checks: absence → missing-attribute error;
           ;; wrong type → type-mismatch error.
           ;; (and) short-circuits so attr-type is never called with #f.
           #'(let ([%%v (mlir::Operation::getAttr op attr-name)])
               (and (or %%v    (begin (mlir::Operation::emitError op err-absent) #f))
                    (or (attr-type %%v) (begin (mlir::Operation::emitError op err-type) #f)))))]
        [(:optional)
         (with-syntax ([attr-name name-str]
                       [attr-type type-stx]
                       [err-msg   (string-append "type mismatch: (" type-str " "
                                                 name-str ") must be #t when present"
                                                 loc-str)])
           #'(let ([%%v (mlir::Operation::getAttr op attr-name)])
               (or (not %%v)
                   (attr-type %%v)
                   (begin (mlir::Operation::emitError op err-msg) #f))))])))

  ;; %%<op>:verify-attributes — checks each declared attribute.
  (define (%%generate-verify-attributes ctx full-name op)
    (let ([attrs (op-parse-attributes op)])
      (if (null? attrs)
          '()
          (with-syntax
              ([verify!     (%%id ctx "%%" full-name ":verify-attributes")]
               [(check ...) (map (lambda (f) (%%gen-attr-check ctx f)) attrs)])
            (list #'(define (verify! op) (and check ...)))))))

  ;; %%<op>:verify-operands — stub until operand-field modifier logic is wired.
  (define (%%generate-verify-operands ctx full-name op)
    '())

  ;; Aggregate all verifiers for one op.
  (define (generate-verifier ctx full-name op)
    (append
     (%%generate-verify-attributes ctx full-name op)
     (%%generate-verify-operands   ctx full-name op)))
  )
