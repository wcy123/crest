;; Macros for defining MLIR ops and dialects in Scheme.
;;
;; define-mlir-op      — standalone op definition (analogous to one ODS op def)
;; define-mlir-dialect — dialect + all its ops (analogous to one .td file)
(library (crest op)
  (export define-mlir-op
          define-mlir-dialect)
  (import (chezscheme)
          (for (crest op expand) expand)   ; %%expand-op-defs at macro-expansion time
          (crest dialect)
          (mlir IR Operation))

  ;; -------------------------------------------------------------------------
  ;; define-mlir-op — standalone op definition
  ;;
  ;; (define-mlir-op toy.constant
  ;;   :summary    "..."                    ; documentation only — no runtime home
  ;;   :description "..."                   ; documentation only
  ;;   :operands   ((input  mlir::Value))
  ;;   :attributes ((value  mlir::DenseElementsAttr))
  ;;   :results    ((output mlir::RankedTensorType)))
  ;;
  ;; Generates: toy.constant?  toy.constant:input  toy.constant:value
  ;;            toy.constant:output  toy.constant:register!
  ;; -------------------------------------------------------------------------
  (define-syntax define-mlir-op
    (lambda (stx)
      (syntax-case stx ()
        [(_ op-name rest ...)
         (let* ([n      (syntax->datum #'op-name)]
                [n-str  (if (string? n) n (symbol->string n))]
                [plist  (syntax->datum #'(rest ...))]
                [defs   (%%expand-op-defs #'op-name n-str plist)]
                [reg-id (datum->syntax #'op-name
                                       (string->symbol (string-append n-str ":register!")))])
           (with-syntax ([(op-def ...) defs]
                         [!register    reg-id]
                         [op-name-s    n-str])
             #'(begin
                 op-def ...
                 (define (!register dialect-ptr)
                   (register-dynamic-op! dialect-ptr op-name-s)))))])))

  ;; -------------------------------------------------------------------------
  ;; define-mlir-dialect — dialect + ops in one declaration
  ;;
  ;; (define-mlir-dialect toy              ; symbol → MLIR name "toy"
  ;;   [:name "override"]                  ; optional name override
  ;;   (define-op constant                 ; auto-prefixed → "toy.constant"
  ;;     :attributes ((value  mlir::DenseElementsAttr))
  ;;     :results    ((output mlir::RankedTensorType)))
  ;;   (define-op print
  ;;     :operands ((input mlir::Value))))
  ;;
  ;; Generates all accessors/predicates for each op, plus:
  ;;   %%toy:initialize (dialect-ptr)  — auto-registers all ops
  ;;   toy:register!    (ctx)          — registers dialect into MLIRContext
  ;; -------------------------------------------------------------------------
  (define-syntax define-mlir-dialect
    (lambda (stx)
      ;; Scan one element at a time — clause list mixes keyword-value pairs
      ;; with (define-op ...) forms, so cddr stepping would skip forms.
      (define (find-name plist default)
        (let loop ([rest plist])
          (cond [(null? rest)               default]
                [(eq? (car rest) ':name)
                 (if (null? (cdr rest)) default (cadr rest))]
                [else                       (loop (cdr rest))])))
      (define (define-op-clause? c)
        (and (pair? c) (eq? (car c) 'define-op)))

      (syntax-case stx ()
        [(_ dialect-sym clause ...)
         (let* ([d-sym      (syntax->datum #'dialect-sym)]
                [plist      (syntax->datum #'(clause ...))]
                [d-str      (find-name plist (symbol->string d-sym))]
                [prefix     (string-append d-str ".")]
                [op-clauses (filter define-op-clause? plist)]
                [op-names   (map (lambda (c)
                                   (string-append prefix
                                                  (symbol->string (cadr c))))
                                 op-clauses)]
                [make-id    (lambda (sfx)
                              (datum->syntax #'dialect-sym
                                             (string->symbol sfx)))]
                [init-id    (make-id (string-append
                                      "%%" (symbol->string d-sym) ":initialize"))]
                [reg-id     (make-id (string-append
                                      (symbol->string d-sym) ":register!"))]
                [all-defs   (apply append
                                   (map (lambda (c)
                                          (%%expand-op-defs
                                           #'dialect-sym
                                           (string-append prefix (symbol->string (cadr c)))
                                           (cddr c)))
                                        op-clauses))])
           (with-syntax
               ([%%init      init-id]
                [!register   reg-id]
                [d-name-s    d-str]
                [(op-def ...) all-defs]
                [(op-name-s ...) (map (lambda (n)
                                        (datum->syntax #'dialect-sym n))
                                      op-names)])
             #'(begin
                 op-def ...
                 (define (%%init dialect-ptr)
                   (register-dynamic-op! dialect-ptr op-name-s) ...)
                 (define (!register ctx)
                   (register-dialect! ctx d-name-s
                                      ':initialize %%init)))))]))
    ))
