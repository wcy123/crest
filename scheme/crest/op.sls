;; define-mlir-op — standalone op definition (analogous to one ODS op def)
;;
;; (define-mlir-op toy.constant
;;   :summary    "..."                    ; documentation only — no runtime home
;;   :description "..."                   ; documentation only
;;   :operands   ((input  mlir::Value))
;;   :attributes ((value  mlir::DenseElementsAttr))
;;   :results    ((output mlir::RankedTensorType)))
;;
;; Generates: isa-toy.constant?
;;            toy.constant-input  toy.constant-value  toy.constant-output
;;            toy.constant:register!
(library (crest op)
  (export define-mlir-op)
  (import (chezscheme)
          (for (crest op expand) expand)
          (crest dialect)
          (mlir IR Operation))

  (define-syntax define-mlir-op
    (lambda (stx)
      (syntax-case stx ()
        [(_ op-name rest ...)
         (let* ([n           (syntax->datum #'op-name)]
                [n-str       (if (string? n) n (symbol->string n))]
                [plist       (syntax->datum #'(rest ...))]
                [extract     (lambda (kw)
                               (let loop ([p plist])
                                 (cond [(null? p)        '()]
                                       [(eq? (car p) kw) (cadr p)]
                                       [else             (loop (cddr p))])))]
                [operands    (extract ':operands)]
                [attributes  (extract ':attributes)]
                [results     (extract ':results)]
                [op-defs     (generate-op-defs
                              #'op-name n-str
                              (map (lambda (f) (symbol->string (car f))) operands)
                              (map (lambda (f) (symbol->string (car f))) attributes)
                              (map (lambda (f) (symbol->string (car f))) results))]
                [reg-id      (datum->syntax #'op-name
                                            (string->symbol (string-append n-str ":register!")))])
           (with-syntax ([(op-def ...) op-defs]
                         [!register    reg-id]
                         [op-name-s    n-str])
             #'(begin
                 op-def ...
                 (define (!register dialect-ptr)
                   (register-dynamic-op! dialect-ptr op-name-s)))))])))
  )
