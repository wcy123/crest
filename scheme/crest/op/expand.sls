;; Expand-phase helpers for op code generation.
;; Imported at (for ... expand) by (crest op) and (crest dialect).
(library (crest op expand)
  (export generate-isa
          generate-build
          generate-operand-accessor
          generate-attribute-accessor
          generate-result-accessor
          generate-verifier
          generate-op-defs)
  (import (chezscheme)
          (mlir IR Operation))

  (define (%%id ctx . parts)
    (datum->syntax ctx (string->symbol (apply string-append parts))))

  ;; (isa-<op>? op) → bool
  (define (generate-isa ctx full-name)
    (with-syntax ([isa? (%%id ctx "isa-" full-name "?")]
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
  )
