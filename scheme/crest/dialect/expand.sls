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

  ;; (toy.constant? op) → bool
  (define (generate-isa ctx full-name)
    (with-syntax ([isa?   (%%id ctx full-name "?")]
                  [name-s (symbol->string (syntax->datum full-name))])
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
  ;; field — datum (name type) pair
  (define (generate-attribute-accessor ctx full-name field)
    (with-syntax ([id    (%%id ctx full-name ":" (car field))]
                  [aname (symbol->string (car field))])
      #'(define (id op)
          (mlir::Operation::getAttr op aname))))

  ;; (toy.constant:output op) → mlir::Value  for result at index
  ;; field — datum (name type) pair
  (define (generate-result-accessor ctx full-name field index)
    (with-syntax ([id  (%%id ctx full-name ":" (car field))]
                  [idx index])
      #'(define (id op)
          (mlir::Operation::getResult op idx))))

  ;; (verify-toy.constant op) → bool  — stub until type predicates are wired
  (define (generate-verifier ctx full-name op)
    '())

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
           [name-str  (symbol->string (syntax->datum ctx))]
           [(cb ...)  cb-stxs])
        #'(define (register! ctx)
            (ffi-fn ctx name-str (vector cb ...))))))
  )
