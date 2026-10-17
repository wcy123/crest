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
      [(string? sexp) sexp]              ; Literal strings pass through
      [(symbol? sexp) (symbol->string sexp)] ; Symbols become identifiers
      [(number? sexp) (number->string sexp)] ; Numbers
      [(null? sexp) ""]
      [(list? sexp)
       (case (and (pair? sexp) (car sexp))
         [(class) (format-cpp-class sexp)]
         [(namespace) (format-cpp-namespace sexp)]
         [(function) (format-cpp-function sexp)]
         [(method) (format-cpp-method sexp)]
         [(comment) (format-cpp-comment sexp)]
         [else (error 'sexp->cpp "Unknown construct" sexp)])]
      [else (error 'sexp->cpp "Cannot convert" sexp)]))

  ;; Format: (class Name : Base1 Base2 { body ... })
  (define (format-cpp-class sexp)
    (match sexp
      [`(class ,name : ,@bases { ,@body })
       (string-append
         "class " (sexp->cpp name) " : "
         (string-join (map sexp->cpp bases) ", ")
         " {\n"
         (indent-block (string-join (map sexp->cpp body) "\n"))
         "\n};\n")]
      [_ (error 'format-cpp-class "Invalid class syntax" sexp)]))

  ;; Format: (namespace Name { body ... })
  (define (format-cpp-namespace sexp)
    (match sexp
      [`(namespace ,name { ,@body })
       (string-append
         "namespace " (sexp->cpp name) " {\n"
         (string-join (map sexp->cpp body) "\n")
         "\n} // namespace " (sexp->cpp name) "\n")]
      [_ (error 'format-cpp-namespace "Invalid namespace syntax" sexp)]))

  ;; Format: (function return-type name (params ...) body)
  (define (format-cpp-function sexp)
    (match sexp
      [`(function ,ret-type ,name (,@params) ,body)
       (string-append
         (sexp->cpp ret-type) " "
         (sexp->cpp name)
         "(" (string-join (map sexp->cpp params) ", ") ")"
         (if (equal? body ';)
             ";\n"
             (string-append " {\n"
                           (indent-block (sexp->cpp body))
                           "\n}\n")))]
      [_ (error 'format-cpp-function "Invalid function syntax" sexp)]))

  ;; Format: (method access-spec return-type name (params ...) qualifiers body)
  ;; Example: (method public void foo () const ;)
  (define (format-cpp-method sexp)
    (match sexp
      [`(method ,access ,ret-type ,name (,@params) ,@rest)
       (let* ([has-qualifiers (and (pair? rest)
                                   (member (car rest) '(const override final virtual)))]
              [qualifiers (if has-qualifiers
                              (if (list? (car rest))
                                  (car rest)
                                  (list (car rest)))
                              '())]
              [body (if has-qualifiers (cadr rest) (car rest))])
         (string-append
           (sexp->cpp access) ":\n"
           "  " (sexp->cpp ret-type) " "
           (sexp->cpp name)
           "(" (string-join (map sexp->cpp params) ", ") ")"
           (if (null? qualifiers)
               ""
               (string-append " " (string-join (map sexp->cpp qualifiers) " ")))
           (if (equal? body ';)
               ";\n"
               (string-append " {\n"
                             (indent-block (sexp->cpp body))
                             "\n  }\n"))))]
      [_ (error 'format-cpp-method "Invalid method syntax" sexp)]))

  ;; Format: (comment "text")
  (define (format-cpp-comment sexp)
    (match sexp
      [`(comment ,text)
       (string-append "// " text "\n")]
      [_ (error 'format-cpp-comment "Invalid comment syntax" sexp)]))

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

  ;; R6RS match macro (simplified)
  (define-syntax match
    (syntax-rules (quote unquote quasiquote)
      [(_ expr [pattern body ...] ...)
       (let ([val expr])
         (cond
           [(match-pattern val 'pattern) body ...] ...
           [else (error 'match "No matching pattern" val)]))]))

  ;; Simple pattern matcher for quasiquote patterns
  (define (match-pattern val pattern)
    (cond
      [(and (pair? pattern) (eq? (car pattern) 'quasiquote))
       (match-quasiquote val (cadr pattern))]
      [else (equal? val pattern)]))

  (define (match-quasiquote val pattern)
    (cond
      [(and (pair? pattern) (eq? (car pattern) 'unquote))
       #t]  ; Any value matches ,x
      [(and (pair? pattern) (eq? (car pattern) 'unquote-splicing))
       (list? val)]  ; Must be list for ,@x
      [(pair? pattern)
       (and (pair? val)
            (match-quasiquote (car val) (car pattern))
            (match-quasiquote (cdr val) (cdr pattern)))]
      [else (equal? val pattern)]))
)
