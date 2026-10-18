;; Macro for defining MLIR ops in Scheme — analogous to ODS in C++.
;;
;; (define-mlir-op toy.constant
;;   :summary    "A constant tensor"          ; documentation only, not stored at runtime
;;   :description "..."                       ; documentation only, not stored at runtime
;;   :operands   ((input  mlir::Value))       ; Value operands — accessed by getOperand(i)
;;   :attributes ((value  mlir::DenseElementsAttr))  ; Attr inputs — accessed by getAttr(name)
;;   :results    ((output mlir::RankedTensorType)))   ; Value results — accessed by getResult(i)
;;
;; Generates for each op:
;;   (toy.constant?          op)        — predicate
;;   (toy.constant:input     op)        — operand accessor
;;   (toy.constant:value     op)        — attribute accessor
;;   (toy.constant:output    op)        — result accessor
;;   (toy.constant:register! d)         — register the op into a CrestDialect
(library (crest op)
  (export define-mlir-op)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation))

  (define-syntax define-mlir-op
    (lambda (stx)
      ;; Extract a keyword's value from a flat plist datum.
      (define (extract-kw kw plist default)
        (let loop ([rest plist])
          (cond [(null? rest)       default]
                [(eq? (car rest) kw) (cadr rest)]
                [else               (loop (cddr rest))])))

      (syntax-case stx ()
        [(_ op-name rest ...)
         (let* ([plist      (syntax->datum #'(rest ...))]
                [name-str   (let ([n (syntax->datum #'op-name)])
                              (if (string? n) n (symbol->string n)))]
                [operands   (extract-kw ':operands   plist '())]
                [attributes (extract-kw ':attributes plist '())]
                [results    (extract-kw ':results    plist '())]
                ;; :summary and :description are accepted but silently ignored —
                ;; they serve as structured comments with no runtime destination.
                [make-id    (lambda (sfx)
                              (datum->syntax #'op-name
                                             (string->symbol
                                              (string-append name-str ":" sfx))))]
                [pred-id    (datum->syntax #'op-name
                                           (string->symbol (string-append name-str "?")))])
           (with-syntax
               ([?pred      pred-id]
                [!register  (make-id "register!")]
                [op-name-s  name-str]
                ;; Operand accessors — indexed by position
                [(operand-def ...)
                 (let loop ([fs operands] [i 0])
                   (if (null? fs) '()
                       (cons (with-syntax ([id  (make-id (symbol->string (caar fs)))]
                                           [idx i])
                               #'(define (id op)
                                   (mlir::Operation::getOperand op idx)))
                             (loop (cdr fs) (+ i 1)))))]
                ;; Attribute accessors — looked up by name string
                [(attr-def ...)
                 (map (lambda (f)
                        (with-syntax ([id    (make-id (symbol->string (car f)))]
                                      [aname (symbol->string (car f))])
                          #'(define (id op)
                              (mlir::Operation::getAttr op aname))))
                      attributes)]
                ;; Result accessors — indexed by position
                [(result-def ...)
                 (let loop ([fs results] [i 0])
                   (if (null? fs) '()
                       (cons (with-syntax ([id  (make-id (symbol->string (caar fs)))]
                                           [idx i])
                               #'(define (id op)
                                   (mlir::Operation::getResult op idx)))
                             (loop (cdr fs) (+ i 1)))))])
             #'(begin
                 (define (?pred op)
                   (string=? (mlir::Operation::getName op) op-name-s))
                 operand-def ...
                 attr-def ...
                 result-def ...
                 (define (!register dialect-ptr)
                   (register-dynamic-op! dialect-ptr op-name-s)))))]))
    ))
