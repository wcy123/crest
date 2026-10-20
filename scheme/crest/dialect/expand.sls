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
          (crest dialect ast)
          (mlir IR Operation))

  (define (%%id ctx . parts)
    (datum->syntax ctx (string->symbol (apply string-append parts))))

  ;; (toy.constant? op) → bool
  (define (generate-isa ctx full-name)
    (with-syntax ([isa? (%%id ctx full-name "?")]
                  [n    full-name])
      #'(define (isa? op)
          (string=? (mlir::Operation::getName op) n))))

  ;; (build-<op> ...) — stub until builder bindings are ready
  (define (generate-build ctx full-name op)
    '())

  ;; (toy.constant:input op) → mlir::Value  for operand at index
  ;; field — operand-field record
  (define (generate-operand-accessor ctx full-name field index)
    (with-syntax ([id  (%%id ctx full-name ":"
                             (symbol->string (syntax->datum (operand-field-name field))))]
                  [idx index])
      #'(define (id op)
          (mlir::Operation::getOperand op idx))))

  ;; (toy.constant:value op) → mlir::Attribute  for named attribute
  ;; field — datum (name type) pair
  (define (generate-attribute-accessor ctx full-name field)
    (with-syntax ([id    (%%id ctx full-name ":" (symbol->string (car field)))]
                  [aname (symbol->string (car field))])
      #'(define (id op)
          (mlir::Operation::getAttr op aname))))

  ;; (toy.constant:output op) → mlir::Value  for result at index
  ;; field — datum (name type) pair
  (define (generate-result-accessor ctx full-name field index)
    (with-syntax ([id  (%%id ctx full-name ":" (symbol->string (car field)))]
                  [idx index])
      #'(define (id op)
          (mlir::Operation::getResult op idx))))

  ;; (verify-toy.constant op) → bool  — stub until type predicates are wired
  (define (generate-verifier ctx full-name op)
    '())

  ;; All definitions for one op.
  ;; op — op-parse record
  (define (generate-op-defs ctx full-name op)
    (append
     (list (generate-isa ctx full-name))
     (generate-build ctx full-name op)
     (let loop ([fields (op-parse-operands op)] [i 0])
       (if (null? fields) '()
           (cons (generate-operand-accessor ctx full-name (car fields) i)
                 (loop (cdr fields) (+ i 1)))))
     (map (lambda (f) (generate-attribute-accessor ctx full-name f))
          (op-parse-attributes op))
     (let loop ([fields (op-parse-results op)] [i 0])
       (if (null? fields) '()
           (cons (generate-result-accessor ctx full-name (car fields) i)
                 (loop (cdr fields) (+ i 1)))))
     (generate-verifier ctx full-name op)))

  ;; All op definitions for a dialect — flattened list of syntax objects.
  ;; ops — list of op-parse records
  (define (generate-all-op-defs ctx ops)
    (let ([op-prefix (string-append (symbol->string (syntax->datum ctx)) ".")])
      (apply append
             (map (lambda (op)
                    (generate-op-defs
                     ctx
                     (string-append op-prefix
                                    (symbol->string (syntax->datum (op-parse-name op))))
                     op))
                  ops))))

  ;; (toy:register! ctx) — registers the dialect with all its callbacks.
  ;; ctx derives the dialect name; cbs — 12-slot vector of syntax-or-#f.
  (define (generate-register-dialect ctx cbs)
    (let* ([dialect-name (symbol->string (syntax->datum ctx))]
           [cb-stxs      (map (lambda (i) (or (vector-ref cbs i) #'#f))
                              '(0 1 2 3 4 5 6 7 8 9 10 11))])
      (with-syntax
          ([register! (%%id ctx dialect-name ":register!")]
           [ffi-fn    (%%id ctx "%crest::register-dialect!")]
           [name-str  (datum->syntax ctx dialect-name)]
           [(cb ...)  cb-stxs])
        #'(define (register! ctx)
            (ffi-fn ctx name-str (vector cb ...))))))
  )
