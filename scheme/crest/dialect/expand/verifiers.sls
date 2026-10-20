;; Verifier code generators for define-dialect ops.
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp verify() methods.
(library (crest dialect expand verifiers)
  (export generate-verifier
          generate-op-verify-slot)
  (import (chezscheme)
          (crest dialect ast)
          (crest dialect expand utils)
          (crest pattern-dsl srcloc)
          (mlir IR Operation))

  ;; Single attribute check — returns a CHECK FORM (not a define).
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

  ;; Collect all check forms for an op — attributes + operands (stub).
  (define (%%all-check-forms ctx op)
    (append
     (map (lambda (f) (%%gen-attr-check ctx f)) (op-parse-attributes op))
     '()))  ; operand checks added here when implemented

  ;; Combine generated and user-provided :verify callbacks.
  ;; Generated verifier runs first; user's verifier owns its own diagnostics.
  (define (generate-op-verify-slot ctx full-name op user-verifier)
    (let ([verifier (%%generate-verifier-ref ctx full-name op)])
      (cond
       [(and verifier user-verifier)
        (with-syntax ([generated verifier] [user user-verifier])
          #'(lambda (op) (and (generated op) (user op))))]
       [else (or verifier user-verifier #'#f)])))

  ;; generate-verifier: returns a list with one %%<op>:verify define, or empty.
  ;; %%<op>:verify is the single entry point registered as the :verify callback.
  (define (generate-verifier ctx full-name op)
    (let ([checks (%%all-check-forms ctx op)])
      (if (null? checks)
          '()
          (with-syntax
              ([verify!     (%%id ctx "%%" full-name ":verify")]
               [(check ...) checks])
            (list #'(define (verify! op) (and check ...)))))))

  ;; %%generate-verifier-ref: returns #'%%<op>:verify syntax if the op has checks,
  ;; or #f if no verifier is needed.  Used by generate-initialize to wire :verify.
  (define (%%generate-verifier-ref ctx full-name op)
    (if (null? (%%all-check-forms ctx op))
        #f
        (%%id ctx "%%" full-name ":verify")))
  )
