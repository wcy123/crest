;; User-facing DSL for defining MLIR dialects

(library (mlir codegen dialect-dsl)
  (export define-dialect)

  (import (chezscheme)
          (mlir codegen semantic-model))

  (define-syntax define-dialect
    (lambda (stx)
      (define (extract-kw kw args default)
        (let loop ([args args])
          (cond
           [(null? args) default]
           [(and (pair? args)
                 (equal? (syntax->datum (car args)) kw))
            (cadr args)]
           [else (loop (cdr args))])))
      (syntax-case stx ()
        [(_ kw-arg ...)
         (let* ([args (syntax->list #'(kw-arg ...))]
                [get  (lambda (kw default) (extract-kw kw args default))])
           (with-syntax
               ([name    (get ':name                          #'"")]
                [ns      (get ':cpp-namespace                 #'"")]
                [desc    (get ':description                   #'"")]
                [deps    (get ':depends-on                    #''())]
                [attr-p  (get ':use-default-attr-printer      #'#t)]
                [type-p  (get ':use-default-type-printer      #'#t)]
                [cmater  (get ':has-constant-materializer     #'#f)]
                [canon   (get ':has-canonicalizer             #'#f)]
                [opattr  (get ':has-op-attr-verify            #'#f)]
                [rgarg   (get ':has-region-arg-attr-verify    #'#f)]
                [rgres   (get ':has-region-result-attr-verify #'#f)]
                [dtor    (get ':has-non-default-destructor    #'#f)]
                [iface   (get ':has-op-interface-fallback     #'#f)]
                [extra   (get ':extra-class-decl              #'#f)])
             ;; Coerce symbol values for string fields (allows :name 'foo or :name "foo")
             #'(make-dialect
                (let ([v name]) (if (symbol? v) (symbol->string v) v))
                (let ([v ns])   (if (symbol? v) (symbol->string v) v))
                desc deps
                attr-p type-p
                cmater canon opattr rgarg rgres dtor iface
                extra)))])))
  )
