#!chezscheme
;; S-expression to C++ pretty printer
;; Converts structured C++ (as S-expressions) to text

(library (mlir codegen cpp-printer)
  (export sexp->cpp
          format-cpp-class
          format-cpp-function
          format-cpp-namespace)

  (import (chezscheme))

  ;; Main entry point: convert S-expression to C++ string
  (define (sexp->cpp sexp)
    (cond
     [(string? sexp) sexp]
     [(symbol? sexp) (symbol->string sexp)]
     [(number? sexp) (number->string sexp)]
     [(null? sexp) ""]
     [(list? sexp)
      (case (car sexp)
        [(class)     (format-cpp-class sexp)]
        [(namespace) (format-cpp-namespace sexp)]
        [(function)  (format-cpp-function sexp)]
        [(method)    (format-cpp-method sexp)]
        [(comment)      (format-cpp-comment sexp)]
        [(string-lit)   (string-append "\"" (cadr sexp) "\"")]
        [(stmt)         (string-append (cadr sexp) ";")]
        [(begin)     (format-cpp-begin sexp)]
        [(return)    (format-cpp-return sexp)]
        [else (format-cpp-call sexp)])]
     [(boolean? sexp) ""]   ; #f = forward declaration (no body)
     [else (error 'sexp->cpp "Cannot convert" sexp)]))

  ;; (class Name : Base1 Base2 { member ... })
  ;; { and } are literal symbols in the list
  (define (format-cpp-class sexp)
    ;; sexp = (class name : base ... { member ... })
    (let* ([name    (cadr sexp)]
           [after-name (cddr sexp)]  ; (: base ... { member ... })
           [_colon  (car after-name)]
           [rest    (cdr after-name)]
           ;; collect bases until we hit the { symbol
           [lbrace  (list-index (lambda (x) (equal? x (string->symbol "{"))) rest)]
           [bases   (list-head rest lbrace)]
           [after-brace (list-tail rest (+ lbrace 1))]
           ;; collect body until the } symbol
           [rbrace  (list-index (lambda (x) (equal? x (string->symbol "}"))) after-brace)]
           [body    (list-head after-brace rbrace)])
      (string-append
       "class " (sexp->cpp name) " : "
       (string-join (map sexp->cpp bases) " ")
       " {\n"
       (indent-block (string-join (filter (lambda (s) (not (string=? s "")))
                                          (map sexp->cpp body)) "\n"))
       "\n};\n")))

  ;; (namespace name { body ... })
  (define (format-cpp-namespace sexp)
    (let* ([name       (cadr sexp)]
           [after-name (cddr sexp)]
           [lbrace     (list-index (lambda (x) (equal? x (string->symbol "{"))) after-name)]
           [after-brace (list-tail after-name (+ lbrace 1))]
           [rbrace     (list-index (lambda (x) (equal? x (string->symbol "}"))) after-brace)]
           [body       (list-head after-brace rbrace)])
      (string-append
       "namespace " (sexp->cpp name) " {\n"
       (string-join (filter (lambda (s) (not (string=? s "")))
                            (map sexp->cpp body)) "\n")
       "\n} // namespace " (sexp->cpp name) "\n")))

  ;; (function ret-type name (params ...) body)
  (define (format-cpp-function sexp)
    (let ([ret-type (cadr sexp)]
          [name     (caddr sexp)]
          [params   (cadddr sexp)]
          [body     (if (null? (cddddr sexp)) #f (car (cddddr sexp)))])
      (string-append
       (sexp->cpp ret-type) " "
       (sexp->cpp name)
       "(" (string-join (map format-cpp-param params) ", ") ")"
       (if (not body)
           ";\n"
           (string-append " {\n"
                          (indent-block (sexp->cpp body))
                          "\n}\n")))))

  ;; (method access pre-specifier... ret-type name (params ...) post-qualifier... body)
  ;; access = public/private/protected
  ;; pre-specifiers = static, constexpr, explicit, virtual, "explicit" (strings), etc.
  ;; params = first list element after name
  ;; post-qualifiers = const, override, final after params
  ;; body = last element (#f = forward decl, sexp = implementation)
  (define (format-cpp-method sexp)
    (let* ([access   (cadr sexp)]
           [items    (cddr sexp)]          ; everything after access
           ;; find params: first list element
           [params-idx (list-index list? items)]
           [before-params (list-head items params-idx)]
           [params   (list-ref items params-idx)]
           [after-params (list-tail items (+ params-idx 1))]
           ;; name is last atom before params; specifiers+ret-type are before name
           [name     (list-ref before-params (- (length before-params) 1))]
           [ret+spec (list-head before-params (- (length before-params) 1))]
           [qualifier-syms '(const override final)]
           [qualifiers (filter (lambda (x) (and (symbol? x) (memq x qualifier-syms))) after-params)]
           [body     (let ([non-quals (filter (lambda (x)
                                                (not (and (symbol? x) (memq x qualifier-syms))))
                                              after-params)])
                       (if (null? non-quals) #f (car non-quals)))])
      (string-append
       (sexp->cpp access) ":\n"
       "  "
       (if (null? ret+spec) "" (string-append (string-join (map sexp->cpp ret+spec) " ") " "))
       (sexp->cpp name)
       "(" (string-join (map format-cpp-param params) ", ") ")"
       (if (null? qualifiers)
           ""
           (string-append " " (string-join (map sexp->cpp qualifiers) " ")))
       (if (not body)
           ";\n"
           (string-append " {\n"
                          (indent-block (sexp->cpp body))
                          "\n  }\n")))))

  ;; (func arg1 arg2 ...) — generic function/constructor call
  (define (format-cpp-call sexp)
    (string-append
     (sexp->cpp (car sexp))
     "(" (string-join (map sexp->cpp (cdr sexp)) ", ") ")"))

  ;; (type name) or (type &name) — function parameter
  (define (format-cpp-param param)
    (string-join (map sexp->cpp param) " "))

  ;; (comment "text")
  (define (format-cpp-comment sexp)
    (string-append "// " (cadr sexp) "\n"))

  ;; (begin stmt ...)
  (define (format-cpp-begin sexp)
    (string-join (map sexp->cpp (cdr sexp)) "\n"))

  ;; (return expr)
  (define (format-cpp-return sexp)
    (string-append "return " (sexp->cpp (cadr sexp)) ";"))

  ;; Helper: indent each line by 2 spaces
  (define (indent-block str)
    (let ([lines (string-split str #\newline)])
      (string-join
       (map (lambda (line)
              (if (string=? line "")
                  line
                  (string-append "  " line)))
            lines)
       "\n")))

  ;; Helper: join strings with separator
  (define (string-join strs sep)
    (if (null? strs)
        ""
        (fold-left
         (lambda (acc s)
           (if (string=? acc "")
               s
               (string-append acc sep s)))
         ""
         strs)))

  ;; Helper: split string by delimiter
  (define (string-split str delim)
    (let loop ([chars (string->list str)]
               [current '()]
               [result '()])
      (cond
       [(null? chars)
        (reverse (cons (list->string (reverse current)) result))]
       [(char=? (car chars) delim)
        (loop (cdr chars)
              '()
              (cons (list->string (reverse current)) result))]
       [else
        (loop (cdr chars)
              (cons (car chars) current)
              result)])))

  ;; Helper: first index where predicate is true
  (define (list-index pred lst)
    (let loop ([lst lst] [i 0])
      (cond
       [(null? lst) (error 'list-index "element not found")]
       [(pred (car lst)) i]
       [else (loop (cdr lst) (+ i 1))])))
  )
