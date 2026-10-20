;; expand-macro tool — pretty-prints macro expansions found in a Scheme source file.
;; Invoked via crest-opt by the tools/expand-macro shell script.
(library (tools expand-macro)
  (export run-pass)
  (import (chezscheme)
          (crest dialect))

  ;; Read all top-level s-expressions from a file.
  (define (%%read-all-forms file)
    (with-input-from-file file
      (lambda ()
        (let loop ([acc '()])
          (let ([form (read)])
            (if (eof-object? form)
                (reverse acc)
                (loop (cons form acc))))))))

  ;; Recursively walk an s-expression and collect all (name ...) sub-forms.
  (define (%%find-forms name form)
    (cond
     [(not (pair? form)) '()]
     [(eq? (car form) name) (list form)]
     [else (apply append (map (lambda (f) (%%find-forms name f)) form))]))

  ;; Seed the interaction environment with the macros we need to expand.
  (define %%env-ready #f)
  (define (%%ensure-env)
    (unless %%env-ready
      (eval '(import (crest dialect)) (interaction-environment))
      (set! %%env-ready #t)))

  (define (%%expand form)
    (%%ensure-env)
    (eval `(expand ',form) (interaction-environment)))

  ;; Rewrite Chez compilation artifacts back to readable Scheme at datum level.
  ;;
  ;;   (set! f (lambda args body))     → (define (f . args) body)
  ;;   (($top-level-value 'name) ...)  → (name ...)
  ;;   ($invoke-library ...)           → dropped
  ;;   #N%-prefixed symbols            → symbol without prefix
  (define (%%prettify form)

    (define (%%strip-sym s)
      (let ([str (symbol->string s)])
        (let loop ([i 0])
          (cond
           [(= i (string-length str)) s]
           [(and (char=? (string-ref str i) #\%)
                 (> i 0))
            (string->symbol (substring str (+ i 1) (string-length str)))]
           [else (loop (+ i 1))]))))

    (define (%%top-level-ref? f)
      (and (pair? f)
           (symbol? (car f))
           (eq? (%%strip-sym (car f)) '$top-level-value)
           (pair? (cdr f))
           (pair? (cadr f))
           (eq? (car (cadr f)) 'quote)))

    (define (%%invoke-library? f)
      (and (pair? f) (symbol? (car f))
           (eq? (%%strip-sym (car f)) '$invoke-library)))

    (define (%%walk f)
      (cond
       [(symbol? f) (%%strip-sym f)]
       [(not (pair? f)) f]
       ;; drop ($invoke-library ...) entirely
       [(%%invoke-library? f) #f]
       ;; (set! name (lambda args body)) → (define (name . args) body)
       [(and (symbol? (car f))
             (eq? (%%strip-sym (car f)) 'set!)
             (pair? (cddr f))
             (pair? (caddr f))
             (symbol? (car (caddr f)))
             (eq? (%%strip-sym (car (caddr f))) 'lambda))
        (let* ([name (cadr f)]
               [lam  (caddr f)]
               [args (cadr lam)]
               [body (filter values (map %%walk (cddr lam)))])
          `(define ,(cons name args) ,@body))]
       ;; (($top-level-value 'name) arg ...) → (name arg ...)
       [(and (pair? (car f)) (%%top-level-ref? (car f)))
        (filter values
                (map %%walk `(,(cadr (cadr (car f))) ,@(cdr f))))]
       ;; ($top-level-value 'name) alone → name
       [(%%top-level-ref? f) (cadr (cadr f))]
       ;; (begin f ...) — filter out dropped #f entries
       [(and (symbol? (car f)) (eq? (%%strip-sym (car f)) 'begin))
        `(begin ,@(filter values (map %%walk (cdr f))))]
       [else (filter values (map %%walk f))]))

    (%%walk form))

  (define (run-pass _op)
    (let* ([name    (string->symbol
                     (or (getenv "EXPAND_MACRO_NAME") "define-dialect"))]
           [file    (or (getenv "EXPAND_MACRO_FILE")
                        (error 'expand-macro "EXPAND_MACRO_FILE not set"))]
           [raw     (getenv "EXPAND_MACRO_RAW")]
           [forms   (%%read-all-forms file)]
           [targets (apply append (map (lambda (f) (%%find-forms name f)) forms))])
      (if (null? targets)
          (display (string-append "No (" (symbol->string name)
                                  " ...) found in " file "\n"))
          (parameterize ([print-gensym #f])
            (for-each
             (lambda (form)
               (display (string-append ";; (" (symbol->string name) " ...)\n"))
               (let ([expanded (syntax->datum (%%expand form))])
                 (pretty-print (if raw expanded (%%prettify expanded))))
               (newline))
             targets)))))
  )
