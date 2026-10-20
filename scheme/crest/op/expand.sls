;; Expand-phase helpers for op code generation.
;; Imported at (for ... expand) by (crest op) and (crest dialect).
(library (crest op expand)
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
          (crest dialect ast)
          (mlir IR Operation))

  (define (%%id ctx . parts)
    (datum->syntax ctx (string->symbol (apply string-append parts))))

  (define (%%operand-names operands)
    (map (lambda (f) (symbol->string (syntax->datum (operand-field-name f)))) operands))

  (define (%%field-names fields)
    (map (lambda (f) (symbol->string (car f))) fields))

  ;; (isa-<op>? op) → bool
  (define (generate-isa ctx full-name)
    (with-syntax ([isa? (%%id ctx full-name "?")]
                  [n    full-name])
      #'(define (isa? op)
          (string=? (mlir::Operation::getName op) n))))

  ;; (build-<op> ...) — stub until builder bindings are ready
  (define (generate-build ctx full-name operand-names attr-names result-names)
    '())

  ;; (<op>-<field> op) → mlir::Value  for operand at index
  (define (generate-operand-accessor ctx full-name field-name index)
    (with-syntax ([id  (%%id ctx full-name "-" field-name)]
                  [idx index])
      #'(define (id op)
          (mlir::Operation::getOperand op idx))))

  ;; (<op>-<field> op) → mlir::Attribute  for named attribute
  (define (generate-attribute-accessor ctx full-name field-name)
    (with-syntax ([id    (%%id ctx full-name "-" field-name)]
                  [aname field-name])
      #'(define (id op)
          (mlir::Operation::getAttr op aname))))

  ;; (<op>-<field> op) → mlir::Value  for result at index
  (define (generate-result-accessor ctx full-name field-name index)
    (with-syntax ([id  (%%id ctx full-name "-" field-name)]
                  [idx index])
      #'(define (id op)
          (mlir::Operation::getResult op idx))))

  ;; (verify-<op>-operands op) → bool  — stub until type predicates are wired
  (define (generate-verifier ctx full-name operand-names)
    '())

  ;; All definitions for one op.
  ;; operand-names, attr-names, result-names — lists of strings.
  (define (generate-op-defs ctx full-name operand-names attr-names result-names)
    (append
     (list (generate-isa ctx full-name))
     (generate-build ctx full-name operand-names attr-names result-names)
     (let loop ([names operand-names] [i 0])
       (if (null? names) '()
           (cons (generate-operand-accessor ctx full-name (car names) i)
                 (loop (cdr names) (+ i 1)))))
     (map (lambda (name) (generate-attribute-accessor ctx full-name name))
          attr-names)
     (let loop ([names result-names] [i 0])
       (if (null? names) '()
           (cons (generate-result-accessor ctx full-name (car names) i)
                 (loop (cdr names) (+ i 1)))))
     (generate-verifier ctx full-name operand-names)))

  ;; All op definitions for a dialect — flattened list of syntax objects.
  ;; ctx derives the dialect name (and thus op-name prefix) from the dialect-id syntax.
  (define (generate-all-op-defs ctx ops)
    (let ([op-prefix (string-append (symbol->string (syntax->datum ctx)) ".")])
      (apply append
             (map (lambda (c)
                    (let ([full-name (string-append op-prefix
                                                    (symbol->string (syntax->datum (op-parse-name c))))])
                      (generate-op-defs
                       ctx full-name
                       (%%operand-names (op-parse-operands c))
                       (%%field-names   (op-parse-attributes c))
                       (%%field-names   (op-parse-results c)))))
                  ops))))

  ;; (register-<name>! ctx) — registers the dialect with all its callbacks.
  ;; ctx derives the dialect name; cbs — 12-slot vector of syntax-or-#f.
  (define (generate-register-dialect ctx cbs)
    (let* ([dialect-name (symbol->string (syntax->datum ctx))]
           [cb-stxs      (map (lambda (i) (or (vector-ref cbs i) #'#f))
                              '(0 1 2 3 4 5 6 7 8 9 10 11))])
      (with-syntax
          ([register! (%%id ctx "register-" dialect-name "!")]
           [ffi-fn    (%%id ctx "%crest::register-dialect!")]
           [name-str  (datum->syntax ctx dialect-name)]
           [(cb ...)  cb-stxs])
        #'(define (register! ctx)
            (ffi-fn ctx name-str (vector cb ...))))))
  )
