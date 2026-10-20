;; Expand-phase helpers for op code generation.
;; Imported at (for ... expand) by (crest dialect).
(library (crest dialect expand)
  (export generate-isa
          generate-build
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
          (crest pattern-dsl srcloc)
          (mlir IR Operation))

  ;; Build a syntax identifier from ctx + parts.
  ;; Parts may be strings, symbols, or syntax identifiers.
  (define (%%id ctx . parts)
    (datum->syntax ctx
                   (string->symbol
                    (apply string-append
                           (map (lambda (p)
                                  (cond
                                   [(string? p)     p]
                                   [(identifier? p) (symbol->string (syntax->datum p))]
                                   [(symbol? p)     (symbol->string p)]
                                   [else (error '%%id "expected string, identifier, or symbol" p)]))
                                parts)))))

  ;; Extract the string name from a syntax identifier — same conversion %%id uses internally.
  (define (%%id->str stx) (symbol->string (syntax->datum stx)))

  ;; Extract attribute names as strings from a list of attribute-field records.
  (define (%%attr-names attrs)
    (map (lambda (f) (%%id->str (attribute-field-name f))) attrs))

  ;; (toy.constant? op) → bool
  (define (generate-isa ctx full-name)
    (with-syntax ([isa?   (%%id ctx full-name "?")]
                  [name-s (%%id->str full-name)])
      #'(define (isa? op)
          (string=? (mlir::Operation::getName op) name-s))))

  ;; (build-<op> ...) — stub until builder bindings are ready
  (define (generate-build ctx full-name op)
    '())

  ;; (toy.constant:input op) → mlir::Value  for operand at index
  ;; field — operand-field record (name is a syntax identifier)
  (define (generate-operand-accessor ctx full-name field index)
    (with-syntax ([id  (%%id ctx full-name ":" (operand-field-name field))]
                  [idx index])
      #'(define (id op)
          (mlir::Operation::getOperand op idx))))

  ;; (toy.constant:value op) → mlir::Attribute  for named attribute
  ;; field — attribute-field record
  (define (generate-attribute-accessor ctx full-name field)
    (with-syntax ([id    (%%id ctx full-name ":" (attribute-field-name field))]
                  [aname (%%id->str (attribute-field-name field))])
      #'(define (id op)
          (mlir::Operation::getAttr op aname))))

  ;; (toy.constant:output op) → mlir::Value  for result at index
  ;; field — datum (name type) pair
  (define (generate-result-accessor ctx full-name field index)
    (with-syntax ([id  (%%id ctx full-name ":" (car field))]
                  [idx index])
      #'(define (id op)
          (mlir::Operation::getResult op idx))))

  ;; (%%toy.constant:verify-attributes op) → bool
  ;; Checks each declared attribute satisfies its type predicate.
  ;; In (name type), type is called as (type (getAttr op "name")).
  ;; Generate a single attribute check with an error diagnostic on failure.
  ;; Attribute name, type name, and source location are all compile-time constants.
  (define (%%gen-attr-check ctx field)
    (let* ([name-str  (%%id->str (attribute-field-name field))]
           [type-stx  (attribute-field-type field)]
           [type-str  (%%id->str type-stx)]
           [modifier  (attribute-field-modifier field)]
           ;; Source location of the declaration site in the define-dialect form.
           [loc       (syntax->file+line+col (attribute-field-name field))]
           [loc-str   (if loc
                          (string-append " (declared at " (car loc) ":"
                                         (number->string (cadr loc)) ":"
                                         (number->string (caddr loc)) ")")
                          "")])
      (case modifier
        [(:required)
         (with-syntax ([attr-name name-str]
                       [attr-type type-stx]
                       [err-msg   (string-append "attribute '" name-str
                                                 "' must be a " type-str loc-str)])
           ;; Fetch once: guard against #f (absent) before calling the C predicate.
           #'(let ([%%v (mlir::Operation::getAttr op attr-name)])
               (or (and %%v (attr-type %%v))
                   (begin (mlir::Operation::emitError op err-msg) #f))))]
        [(:optional)
         (with-syntax ([attr-name name-str]
                       [attr-type type-stx]
                       [err-msg   (string-append "attribute '" name-str
                                                 "' must be a " type-str
                                                 " when present" loc-str)])
           #'(let ([%%v (mlir::Operation::getAttr op attr-name)])
               (or (not %%v)
                   (attr-type %%v)
                   (begin (mlir::Operation::emitError op err-msg) #f))))])))

  (define (generate-verify-attributes ctx full-name op)
    (let ([attrs (op-parse-attributes op)])
      (if (null? attrs)
          '()
          (with-syntax
              ([verify!      (%%id ctx "%%" full-name ":verify-attributes")]
               [(check ...)  (map (lambda (f) (%%gen-attr-check ctx f)) attrs)])
            (list
             #'(define (verify! op)
                 (and check ...)))))))

  ;; (%%toy.constant:verify-operands op) → bool  — stub until modifier logic is wired
  (define (generate-verify-operands ctx full-name op)
    '())

  ;; Aggregate all verifiers for one op.
  (define (generate-verifier ctx full-name op)
    (append
     (generate-verify-attributes ctx full-name op)
     (generate-verify-operands   ctx full-name op)))

  ;; All definitions for one op.
  ;; full-name is a syntax identifier built from ctx + op-parse-name.
  (define (generate-op-defs ctx op)
    (let ([full-name (%%id ctx ctx "." (op-parse-name op))])
      (append
       (list (generate-isa ctx full-name))
       (generate-build ctx full-name op)
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

  ;; (toy:register! ctx) — registers the dialect with all its callbacks.
  ;; ctx — dialect-id syntax; cbs — 12-slot vector of syntax-or-#f.
  (define (generate-register-dialect ctx cbs)
    (let ([cb-stxs (map (lambda (i) (or (vector-ref cbs i) #'#f))
                        '(0 1 2 3 4 5 6 7 8 9 10 11))])
      (with-syntax
          ([register! (%%id ctx ctx ":register!")]
           [ffi-fn    (%%id ctx "%crest::register-dialect!")]
           [name-str  (%%id->str ctx)]
           [(cb ...)  cb-stxs])
        #'(define (register! ctx)
            (ffi-fn ctx name-str (vector cb ...))))))
  )
