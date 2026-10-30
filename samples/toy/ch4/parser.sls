;; Recursive descent parser for the Toy language.
;; Mirrors mlir/examples/toy/Ch1/include/toy/Parser.h
;;         mlir/examples/toy/Ch1/toyc.cpp (parseInputFile)
(library (toy ch4 parser)
  (export parse-input-file)
  (import (chezscheme)
          (toy ch4 ast)
          (toy ch4 lexer))

  ;; parseError — mirrors Parser::parseError()
  (define (%%parse-error lex expected context)
    (let ([loc (lexer:last-loc lex)]
          [tok (lexer:cur-tok  lex)])
      (display "Parse error (" (current-error-port))
      (display (location:line loc) (current-error-port))
      (display ", " (current-error-port))
      (display (location:col  loc) (current-error-port))
      (display "): expected '" (current-error-port))
      (display expected (current-error-port))
      (display "' " (current-error-port))
      (display context (current-error-port))
      (display " but got " (current-error-port))
      (display tok (current-error-port))
      (newline (current-error-port)))
    #f)

  ;; -------------------------------------------------------------------------
  ;; parseNumberExpr ::= number
  ;; -------------------------------------------------------------------------
  (define (%%parse-number-expr lex)
    (let ([loc (lexer:last-loc lex)]
          [val (lexer:value    lex)])
      (lexer:consume! lex tok-number)
      (make-number-expr loc val)))

  ;; -------------------------------------------------------------------------
  ;; parseTensorLiteralExpr ::= '[' literalList ']' | number
  ;; -------------------------------------------------------------------------
  (define (%%parse-tensor-literal lex)
    (let ([loc (lexer:last-loc lex)])
      (lexer:consume! lex #\[)
      (let loop ([values '()])
        (let ([elem (if (equal? (lexer:cur-tok lex) #\[)
                        (%%parse-tensor-literal lex)
                        (if (equal? (lexer:cur-tok lex) tok-number)
                            (%%parse-number-expr lex)
                            (%%parse-error lex "<num> or [" "in literal expression")))])
          (if (not elem)
              #f
              (let ([values (append values (list elem))])
                (cond
                 [(equal? (lexer:cur-tok lex) #\])
                  ;; End of list — build dims
                  (lexer:get-next-token! lex)
                  (if (null? values)
                      (%%parse-error lex "<something>" "to fill literal expression")
                      (let* ([dims (list (length values))]
                             ;; If elements are nested literals, append their dims
                             [dims (if (literal-expr? (car values))
                                       (let ([first-dims (literal-expr:dims (car values))])
                                         ;; Sanity: all elements must have same dims
                                         (if (for-all (lambda (v)
                                                        (and (literal-expr? v)
                                                             (equal? (literal-expr:dims v) first-dims)))
                                                      values)
                                             (append dims first-dims)
                                             (begin
                                               (%%parse-error lex "uniform well-nested dimensions"
                                                              "inside literal expression")
                                               #f)))
                                       dims)])
                        (if dims
                            (make-literal-expr loc values dims)
                            #f)))]
                 [(equal? (lexer:cur-tok lex) #\,)
                  (lexer:get-next-token! lex)  ; eat ,
                  (loop values)]
                 [else
                  (%%parse-error lex "] or ," "in literal expression")])))))))

  ;; -------------------------------------------------------------------------
  ;; parseParenExpr ::= '(' expression ')'
  ;; -------------------------------------------------------------------------
  (define (%%parse-paren-expr lex)
    (lexer:get-next-token! lex)  ; eat (
    (let ([v (%%parse-expression lex)])
      (if (not v)
          #f
          (if (not (equal? (lexer:cur-tok lex) #\)))
              (%%parse-error lex ")" "to close expression with parentheses")
              (begin
                (lexer:consume! lex #\))
                v)))))

  ;; -------------------------------------------------------------------------
  ;; parseIdentifierExpr ::= identifier | identifier '(' args ')'
  ;; -------------------------------------------------------------------------
  (define (%%parse-identifier-expr lex)
    (let ([name (lexer:id       lex)]
          [loc  (lexer:last-loc lex)])
      (lexer:get-next-token! lex)  ; eat identifier
      (if (not (equal? (lexer:cur-tok lex) #\())
          ;; Simple variable reference
          (make-var-expr loc name)
          ;; Function call
          (begin
            (lexer:consume! lex #\()
            (let loop ([args '()])
              (if (equal? (lexer:cur-tok lex) #\))
                  (begin
                    (lexer:consume! lex #\))
                    ;; builtin print
                    (if (string=? name "print")
                        (if (= (length args) 1)
                            (make-print-expr loc (car args))
                            (%%parse-error lex "<single arg>" "as argument to print()"))
                        (make-call-expr loc name args)))
                  (let ([arg (%%parse-expression lex)])
                    (if (not arg)
                        #f
                        (let ([args (append args (list arg))])
                          (cond
                           [(equal? (lexer:cur-tok lex) #\))
                            (lexer:consume! lex #\))
                            (if (string=? name "print")
                                (if (= (length args) 1)
                                    (make-print-expr loc (car args))
                                    (%%parse-error lex "<single arg>" "as argument to print()"))
                                (make-call-expr loc name args))]
                           [(equal? (lexer:cur-tok lex) #\,)
                            (lexer:get-next-token! lex)
                            (loop args)]
                           [else
                            (%%parse-error lex ", or )" "in argument list")]))))))))))

  ;; -------------------------------------------------------------------------
  ;; parsePrimary
  ;; -------------------------------------------------------------------------
  (define (%%parse-primary lex)
    (let ([tok (lexer:cur-tok lex)])
      (cond
       [(equal? tok tok-identifier) (%%parse-identifier-expr lex)]
       [(equal? tok tok-number)     (%%parse-number-expr     lex)]
       [(equal? tok #\()            (%%parse-paren-expr      lex)]
       [(equal? tok #\[)            (%%parse-tensor-literal  lex)]
       [(equal? tok #\;)            #f]
       [(equal? tok #\})            #f]
       [else
        (display "unknown token '" (current-error-port))
        (display tok (current-error-port))
        (display "' when expecting an expression\n" (current-error-port))
        #f])))

  ;; -------------------------------------------------------------------------
  ;; getTokPrecedence
  ;; -------------------------------------------------------------------------
  (define (%%tok-precedence tok)
    (cond
     [(equal? tok #\-) 20]
     [(equal? tok #\+) 20]
     [(equal? tok #\*) 40]
     [else -1]))

  ;; -------------------------------------------------------------------------
  ;; parseBinOpRHS
  ;; -------------------------------------------------------------------------
  (define (%%parse-binop-rhs lex expr-prec lhs)
    (let loop ([lhs lhs])
      (let ([tok-prec (%%tok-precedence (lexer:cur-tok lex))])
        (if (< tok-prec expr-prec)
            lhs
            (let ([binop (lexer:cur-tok  lex)]
                  [loc   (lexer:last-loc lex)])
              (lexer:consume! lex binop)
              (let ([rhs (%%parse-primary lex)])
                (if (not rhs)
                    (%%parse-error lex "expression" "to complete binary operator")
                    (let ([next-prec (%%tok-precedence (lexer:cur-tok lex))])
                      (let ([rhs (if (< tok-prec next-prec)
                                     (%%parse-binop-rhs lex (+ tok-prec 1) rhs)
                                     rhs)])
                        (if (not rhs)
                            #f
                            (loop (make-binary-expr loc binop lhs rhs))))))))))))

  ;; -------------------------------------------------------------------------
  ;; parseExpression ::= primary binop rhs
  ;; -------------------------------------------------------------------------
  (define (%%parse-expression lex)
    (let ([lhs (%%parse-primary lex)])
      (if (not lhs) #f
          (%%parse-binop-rhs lex 0 lhs))))

  ;; -------------------------------------------------------------------------
  ;; parseType ::= '<' shape_list '>'
  ;; -------------------------------------------------------------------------
  (define (%%parse-type lex)
    (if (not (equal? (lexer:cur-tok lex) #\<))
        (%%parse-error lex "<" "to begin type")
        (begin
          (lexer:get-next-token! lex)  ; eat <
          (let loop ([shape '()])
            (if (equal? (lexer:cur-tok lex) tok-number)
                (let ([dim (inexact->exact (lexer:value lex))])
                  (lexer:get-next-token! lex)
                  (when (equal? (lexer:cur-tok lex) #\,)
                    (lexer:get-next-token! lex))
                  (loop (append shape (list dim))))
                (if (not (equal? (lexer:cur-tok lex) #\>))
                    (%%parse-error lex ">" "to end type")
                    (begin
                      (lexer:get-next-token! lex)  ; eat >
                      (make-var-type shape))))))))

  ;; -------------------------------------------------------------------------
  ;; parseDeclaration ::= 'var' identifier ['<' shape '>'] '=' expr
  ;; -------------------------------------------------------------------------
  (define (%%parse-declaration lex)
    (if (not (equal? (lexer:cur-tok lex) tok-var))
        (%%parse-error lex "var" "to begin declaration")
        (let ([loc (lexer:last-loc lex)])
          (lexer:get-next-token! lex)  ; eat var
          (if (not (equal? (lexer:cur-tok lex) tok-identifier))
              (%%parse-error lex "identifier" "after 'var' declaration")
              (let ([id (lexer:id lex)])
                (lexer:get-next-token! lex)  ; eat id
                (let ([type (if (equal? (lexer:cur-tok lex) #\<)
                                (%%parse-type lex)
                                (make-var-type '()))])
                  (if (not type)
                      #f
                      (begin
                        (lexer:consume! lex #\=)
                        (let ([expr (%%parse-expression lex)])
                          (if (not expr)
                              #f
                              (make-var-decl-expr loc id type expr)))))))))))

  ;; -------------------------------------------------------------------------
  ;; parseBlock ::= '{' expression_list '}'
  ;; -------------------------------------------------------------------------
  (define (%%parse-block lex)
    (if (not (equal? (lexer:cur-tok lex) #\{))
        (%%parse-error lex "{" "to begin block")
        (begin
          (lexer:consume! lex #\{)
          ;; skip leading semicolons
          (let skip-semi ()
            (when (equal? (lexer:cur-tok lex) #\;)
              (lexer:consume! lex #\;)
              (skip-semi)))
          (let loop ([stmts '()])
            (cond
             [(or (equal? (lexer:cur-tok lex) #\})
                  (equal? (lexer:cur-tok lex) tok-eof))
              (if (not (equal? (lexer:cur-tok lex) #\}))
                  (%%parse-error lex "}" "to close block")
                  (begin
                    (lexer:consume! lex #\})
                    stmts))]
             [else
              (let ([stmt (cond
                           [(equal? (lexer:cur-tok lex) tok-var)
                            (%%parse-declaration lex)]
                           [(equal? (lexer:cur-tok lex) tok-return)
                            (%%parse-return lex)]
                           [else
                            (%%parse-expression lex)])])
                (if (not stmt)
                    #f
                    (if (not (equal? (lexer:cur-tok lex) #\;))
                        (%%parse-error lex ";" "after expression")
                        (begin
                          ;; skip semicolons
                          (let skip-semi ()
                            (when (equal? (lexer:cur-tok lex) #\;)
                              (lexer:consume! lex #\;)
                              (skip-semi)))
                          (loop (append stmts (list stmt)))))))])))))

  ;; -------------------------------------------------------------------------
  ;; parseReturn ::= 'return' [expr] ';'
  ;; -------------------------------------------------------------------------
  (define (%%parse-return lex)
    (let ([loc (lexer:last-loc lex)])
      (lexer:consume! lex tok-return)
      (let ([expr (if (equal? (lexer:cur-tok lex) #\;)
                      #f
                      (%%parse-expression lex))])
        (if (and (not (equal? (lexer:cur-tok lex) #\;))
                 expr)
            (%%parse-error lex ";" "after return expression")
            (make-return-expr loc expr)))))

  ;; -------------------------------------------------------------------------
  ;; parsePrototype ::= 'def' id '(' params ')'
  ;; -------------------------------------------------------------------------
  (define (%%parse-prototype lex)
    (let ([loc (lexer:last-loc lex)])
      (if (not (equal? (lexer:cur-tok lex) tok-def))
          (%%parse-error lex "def" "in prototype")
          (begin
            (lexer:consume! lex tok-def)
            (if (not (equal? (lexer:cur-tok lex) tok-identifier))
                (%%parse-error lex "function name" "in prototype")
                (let ([fn-name (lexer:id lex)])
                  (lexer:consume! lex tok-identifier)
                  (if (not (equal? (lexer:cur-tok lex) #\())
                      (%%parse-error lex "(" "in prototype")
                      (begin
                        (lexer:consume! lex #\()
                        (let loop ([args '()])
                          (if (equal? (lexer:cur-tok lex) #\))
                              (begin
                                (lexer:consume! lex #\))
                                (make-prototype loc fn-name args))
                              (if (not (equal? (lexer:cur-tok lex) tok-identifier))
                                  (%%parse-error lex "identifier" "in parameter list")
                                  (let ([arg-name (lexer:id       lex)]
                                        [arg-loc  (lexer:last-loc lex)])
                                    (lexer:consume! lex tok-identifier)
                                    (let ([args (append args (list (make-var-expr arg-loc arg-name)))])
                                      (cond
                                       [(equal? (lexer:cur-tok lex) #\))
                                        (lexer:consume! lex #\))
                                        (make-prototype loc fn-name args)]
                                       [(equal? (lexer:cur-tok lex) #\,)
                                        (lexer:consume! lex #\,)
                                        (loop args)]
                                       [else
                                        (%%parse-error lex "," "or ')' in parameter list")]))))))))))))))

  ;; -------------------------------------------------------------------------
  ;; parseDefinition ::= prototype block
  ;; -------------------------------------------------------------------------
  (define (%%parse-definition lex)
    (let ([proto (%%parse-prototype lex)])
      (if (not proto)
          #f
          (let ([body (%%parse-block lex)])
            (if (not body)
                #f
                (make-function proto body))))))

  ;; -------------------------------------------------------------------------
  ;; parseModule ::= (definition)*
  ;; -------------------------------------------------------------------------
  (define (%%parse-module lex)
    (lexer:get-next-token! lex)  ; prime the lexer
    (let loop ([fns '()])
      (if (equal? (lexer:cur-tok lex) tok-eof)
          (make-module-ast fns)
          (let ([f (%%parse-definition lex)])
            (if (not f)
                #f
                (loop (append fns (list f))))))))

  ;; -------------------------------------------------------------------------
  ;; parseInputFile — mirrors parseInputFile() in toyc.cpp
  ;; -------------------------------------------------------------------------
  (define (parse-input-file filename)
    (guard (exn [#t (display-condition exn (current-error-port)) #f])
      (let* ([src    (call-with-port (open-input-file filename)
                       (lambda (p) (get-string-all p)))]
             [lexer  (make-lexer-buffer filename src)])
        (%%parse-module lexer))))
  )
