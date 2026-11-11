;; :assembly-format of define-op: an ODS declarative format string (see mlir/docs/DefiningDialects/Operations.md,
;; "Declarative Assembly Format") turned into the :parse and :print callbacks of the op.
;; Imported at expand phase by (crest dialect). Printed spacing follows mlir-tblgen's OpFormatGen.cpp.
(library (crest dialect assembly-format)
  (export generate-assembly-format)
  (import (chezscheme)
          (crest dialect ast)
          (mlir IR Operation)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR BuiltinTypes)
                mlir::IntegerType::get<i8> mlir::IntegerType::get<i16> mlir::IntegerType::get<i32>
                mlir::IntegerType::get<i64> mlir::IndexType::get
                mlir::Float32Type::get mlir::Float64Type::get)
          (only (mlir Interfaces InferTypeOpInterface)
                mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>)
          (mlir IR OpImplementation))

  (define (%%fail fmt-stx message . parts)
    (syntax-violation 'define-op (apply string-append "assembly-format: " message
                                        (map (lambda (p) (if (string? p) p (format "~s" p))) parts))
                      fmt-stx))

  ;; ── Tokens ──────────────────────────────────────────────────────────────────
  ;; A token is (kind value column), kind one of literal variable ident lparen rparen comma question
  ;; caret colon.

  (define (%%ident-char? c)
    (or (char-alphabetic? c) (char-numeric? c) (char=? c #\_) (char=? c #\-)))

  (define (%%tokenize fmt-stx str)
    (let ([n (string-length str)])
      (let loop ([i 0] [tokens '()])
        (if (>= i n)
            (reverse tokens)
            (let ([c (string-ref str i)])
              (cond
               [(char-whitespace? c) (loop (+ i 1) tokens)]
               [(char=? c #\`)
                (let find ([j (+ i 1)])
                  (cond
                   [(>= j n) (%%fail fmt-stx "unterminated literal at column " (number->string i))]
                   [(char=? (string-ref str j) #\`)
                    (loop (+ j 1) (cons (list 'literal (substring str (+ i 1) j) i) tokens))]
                   [else (find (+ j 1))]))]
               [(char=? c #\$)
                (let find ([j (+ i 1)])
                  (if (and (< j n) (let ([d (string-ref str j)]
                                         ) (or (char-alphabetic? d) (char-numeric? d) (char=? d #\_))))
                      (find (+ j 1))
                      (if (= j (+ i 1))
                          (%%fail fmt-stx "expected a variable name after $ at column " (number->string i))
                          (loop j (cons (list 'variable (substring str (+ i 1) j) i) tokens)))))]
               [(char-alphabetic? c)
                (let find ([j i])
                  (if (and (< j n) (%%ident-char? (string-ref str j)))
                      (find (+ j 1))
                      (begin
                        (when (member (substring str i j) %%unsupported-directives)
                          (%%fail fmt-stx "the directive " (substring str i j) " (column " (number->string i)
                                  ") is not supported yet"))
                        (loop j (cons (list 'ident (substring str i j) i) tokens)))))]
               [(char=? c #\() (loop (+ i 1) (cons (list 'lparen "(" i) tokens))]
               [(char=? c #\)) (loop (+ i 1) (cons (list 'rparen ")" i) tokens))]
               [(char=? c #\,) (loop (+ i 1) (cons (list 'comma "," i) tokens))]
               [(char=? c #\?) (loop (+ i 1) (cons (list 'question "?" i) tokens))]
               [(char=? c #\^) (loop (+ i 1) (cons (list 'caret "^" i) tokens))]
               [(char=? c #\:) (loop (+ i 1) (cons (list 'colon ":" i) tokens))]
               [else (%%fail fmt-stx "unexpected character " (string c) " at column " (number->string i))]))))))

  ;; ── Directive tree ──────────────────────────────────────────────────────────
  ;;   (literal "text" column)        (variable "name" anchor? column)   (attr-dict column)
  ;;   (operands column)              (type arg column)  arg: (variable "x") | operands | results
  ;;   (functional-type in out col)   (group (element ...) column)

  (define (%%token-kind t) (car t))
  (define (%%token-value t) (cadr t))
  (define (%%token-column t) (caddr t))

  (define %%unsupported-directives
    '("custom" "prop-dict" "regions" "successors" "oilist" "qualified" "ref" "attr-dict-with-keyword"))

  (define (%%parse-format fmt-stx tokens)
    ;; Parses elements until a closing parenthesis (consumed by the caller) or the end.
    (define (expect kind tokens what)
      (if (and (pair? tokens) (eq? (%%token-kind (car tokens)) kind))
          (cdr tokens)
          (%%fail fmt-stx "expected " what
                  (if (pair? tokens) (string-append " at column " (number->string (%%token-column (car tokens))))
                      " at the end of the format"))))
    (define (parse-arg tokens)
      ;; an argument of type(...) or functional-type(...): $x, operands or results
      (cond
       [(null? tokens) (%%fail fmt-stx "unexpected end of the format")]
       [(eq? (%%token-kind (car tokens)) 'variable)
        (values (list 'variable (%%token-value (car tokens))) (cdr tokens))]
       [(and (eq? (%%token-kind (car tokens)) 'ident)
             (member (%%token-value (car tokens)) '("operands" "results")))
        (values (string->symbol (%%token-value (car tokens))) (cdr tokens))]
       [else (%%fail fmt-stx "expected $variable, operands or results at column "
                     (number->string (%%token-column (car tokens))))]))
    (define (parse-elements tokens in-group?)
      (let loop ([tokens tokens] [elements '()])
        (cond
         [(null? tokens) (values (reverse elements) tokens)]
         [(eq? (%%token-kind (car tokens)) 'rparen)
          (if in-group?
              (values (reverse elements) tokens)
              (%%fail fmt-stx "unbalanced ) at column " (number->string (%%token-column (car tokens)))))]
         [else
          (let ([t (car tokens)] [rest (cdr tokens)])
            (case (%%token-kind t)
              [(literal) (loop rest (cons (list 'literal (%%token-value t) (%%token-column t)) elements))]
              [(variable)
               (if (and (pair? rest) (eq? (%%token-kind (car rest)) 'caret))
                   (loop (cdr rest) (cons (list 'variable (%%token-value t) #t (%%token-column t)) elements))
                   (loop rest (cons (list 'variable (%%token-value t) #f (%%token-column t)) elements)))]
              [(ident)
               (let ([name (%%token-value t)])
                 (cond
                  [(string=? name "attr-dict")
                   (loop rest (cons (list 'attr-dict (%%token-column t)) elements))]
                  [(string=? name "operands")
                   (loop rest (cons (list 'operands (%%token-column t)) elements))]
                  [(string=? name "type")
                   (let*-values ([(rest) (expect 'lparen rest "( after type")]
                                 [(arg rest) (parse-arg rest)]
                                 [(rest) (expect 'rparen rest ") after the argument of type")])
                     (loop rest (cons (list 'type arg (%%token-column t)) elements)))]
                  [(string=? name "functional-type")
                   (let*-values ([(rest) (expect 'lparen rest "( after functional-type")]
                                 [(in rest) (parse-arg rest)]
                                 [(rest) (expect 'comma rest ", between the arguments of functional-type")]
                                 [(out rest) (parse-arg rest)]
                                 [(rest) (expect 'rparen rest ") after the arguments of functional-type")])
                     (loop rest (cons (list 'functional-type in out (%%token-column t)) elements)))]
                  [(member name %%unsupported-directives)
                   (%%fail fmt-stx "the directive " name " (column " (number->string (%%token-column t))
                           ") is not supported yet")]
                  [else (%%fail fmt-stx "unknown directive " name " at column "
                                (number->string (%%token-column t)))]))]
              [(lparen)
               (let*-values ([(inner rest) (parse-elements rest #t)]
                             [(rest) (expect 'rparen rest ") closing the optional group")])
                 (cond
                  [(and (pair? rest) (eq? (%%token-kind (car rest)) 'colon))
                   (%%fail fmt-stx "an else group (column " (number->string (%%token-column (car rest)))
                           ") is not supported yet")]
                  [else
                   (let ([rest (expect 'question rest "? after an optional group")])
                     (loop rest (cons (list 'group inner (%%token-column t)) elements)))]))]
              [(colon) (%%fail fmt-stx "a bare : at column " (number->string (%%token-column t))
                               "; a literal is written between backquotes")]
              [else (%%fail fmt-stx "unexpected " (%%token-value t) " at column "
                            (number->string (%%token-column t)))]))])))
    (let-values ([(elements rest) (parse-elements tokens #f)])
      elements))

  ;; ── The op's fields ─────────────────────────────────────────────────────────

  (define (%%field-names fields name-of)
    (map (lambda (f) (symbol->string (syntax->datum (name-of f)))) fields))

  ;; An operand is (name modifier index); result and attribute fields are names.
  (define (%%operand-table operands)
    (let loop ([fs operands] [i 0] [acc '()])
      (if (null? fs)
          (reverse acc)
          (loop (cdr fs) (+ i 1)
                (cons (list (symbol->string (syntax->datum (operand-field-name (car fs))))
                            (operand-field-modifier (car fs))
                            i)
                      acc)))))

  (define (%%flex-index table)
    (let loop ([t table])
      (cond [(null? t) #f]
            [(eq? (cadr (car t)) ':required) (loop (cdr t))]
            [else (caddr (car t))])))

  ;; ── Checks ──────────────────────────────────────────────────────────────────

  (define punctuation-parsers
    (list (cons ":"  #'mlir::OpAsmParser::parseColon)
          (cons ","  #'mlir::OpAsmParser::parseComma)
          (cons "("  #'mlir::OpAsmParser::parseLParen)
          (cons ")"  #'mlir::OpAsmParser::parseRParen)
          (cons "<"  #'mlir::OpAsmParser::parseLess)
          (cons ">"  #'mlir::OpAsmParser::parseGreater)
          (cons "["  #'mlir::OpAsmParser::parseLSquare)
          (cons "]"  #'mlir::OpAsmParser::parseRSquare)
          (cons "->" #'mlir::OpAsmParser::parseArrow)))

  (define (%%keyword? s)
    (and (> (string-length s) 0)
         (let ([c (string-ref s 0)]) (or (char-alphabetic? c) (char=? c #\_)))
         (let loop ([i 1])
           (or (>= i (string-length s))
               (and (let ([c (string-ref s i)])
                      (or (char-alphabetic? c) (char-numeric? c) (memv c '(#\_ #\$ #\.))))
                    (loop (+ i 1)))))))

  (define (%%check-literal fmt-stx text column)
    (cond
     [(assoc text punctuation-parsers) #t]
     [(%%keyword? text) #t]
     [(member text '("=" "{" "}" "?" "+" "*"))
      (%%fail fmt-stx "the literal `" text "` (column " (number->string column) ") is not supported yet")]
     [(or (string=? text "") (string=? text " "))
      (%%fail fmt-stx "the empty and the space literal (column " (number->string column)
              ") are not supported yet")]
     [else (%%fail fmt-stx "`" text "` (column " (number->string column)
                   ") is neither punctuation nor a keyword")]))

  ;; Checks the tree against the op's fields. Returns nothing; raises a syntax violation.
  (define (%%check fmt-stx elements operand-table attribute-names optional-attribute-names result-names
                   infer-results?)
    (let ([operand-name (lambda (name) (assoc name operand-table))]
          [seen-operands '()] [seen-operand-types '()] [seen-attributes '()] [seen-result-types '()]
          [attr-dict-seen #f] [operands-directive #f] [functional #f])
      (define (once! cell-name name seen what column)
        (when (member name seen)
          (%%fail fmt-stx what name " appears twice (column " (number->string column) ")")))
      (define (visit element in-group)
        (case (car element)
          [(literal) (%%check-literal fmt-stx (cadr element) (caddr element))]
          [(variable)
           (let* ([name (cadr element)] [column (cadddr element)] [entry (operand-name name)])
             (cond
              [(and entry (eq? (cadr entry) ':optional) (not in-group))
               (%%fail fmt-stx "the optional operand $" name " (column " (number->string column)
                       ") must be the first element of a group: ($" name "^ ...)?")]
              [entry
               (once! 'operand name seen-operands "the operand $" column)
               (when operands-directive
                 (%%fail fmt-stx "the operands directive and $" name " both name the operands"))
               (set! seen-operands (cons name seen-operands))]
              [(member name optional-attribute-names)
               (%%fail fmt-stx "the optional attribute $" name " (column " (number->string column)
                       ") is not supported yet")]
              [(member name attribute-names)
               (once! 'attribute name seen-attributes "the attribute $" column)
               (set! seen-attributes (cons name seen-attributes))]
              [(member name result-names)
               (%%fail fmt-stx "$" name " (column " (number->string column)
                       ") is a result; a result appears as type($" name ")")]
              [else (%%fail fmt-stx "$" name " (column " (number->string column)
                            ") is not an operand or an attribute of the op")]))]
          [(operands)
           (when (or operands-directive (pair? seen-operands))
             (%%fail fmt-stx "the operands directive (column " (number->string (cadr element))
                     ") repeats or overlaps operand variables"))
           (set! operands-directive #t)]
          [(attr-dict)
           (when in-group
             (%%fail fmt-stx "attr-dict (column " (number->string (cadr element)) ") cannot be inside a group"))
           (when attr-dict-seen
             (%%fail fmt-stx "attr-dict appears twice (column " (number->string (cadr element)) ")"))
           (set! attr-dict-seen #t)]
          [(type)
           (let ([arg (cadr element)] [column (caddr element)])
             (cond
              [(eq? arg 'operands)
               (%%fail fmt-stx "type(operands) (column " (number->string column)
                       ") is not supported yet; write type($x) for each operand or functional-type")]
              [(eq? arg 'results)
               (when in-group
                 (%%fail fmt-stx "the result types (column " (number->string column) ") cannot be inside a group"))
               (when (null? result-names)
                 (%%fail fmt-stx "type(results) (column " (number->string column) ") but the op has no results"))
               (for-each (lambda (r)
                           (once! 'result r seen-result-types "the type of the result $" column)
                           (set! seen-result-types (cons r seen-result-types)))
                         result-names)]
              [else
               (let* ([name (cadr arg)] [entry (operand-name name)])
                 (cond
                  [entry
                   (when (eq? (cadr entry) ':variadic)
                     (%%fail fmt-stx "type($" name ") of a variadic operand (column " (number->string column)
                             ") is not supported yet; use functional-type"))
                   (once! 'operand-type name seen-operand-types "the type of the operand $" column)
                   (set! seen-operand-types (cons name seen-operand-types))]
                  [(member name result-names)
                   (when in-group
                     (%%fail fmt-stx "the result type type($" name ") (column " (number->string column)
                             ") cannot be inside a group"))
                   (once! 'result name seen-result-types "the type of the result $" column)
                   (set! seen-result-types (cons name seen-result-types))]
                  [else (%%fail fmt-stx "type($" name ") (column " (number->string column)
                                ") is not the type of an operand or a result")]))]))]
          [(functional-type)
           (let ([in (cadr element)] [out (caddr element)] [column (cadddr element)])
             (when (or in-group functional)
               (%%fail fmt-stx "functional-type (column " (number->string column)
                       ") appears twice or inside a group"))
             (unless (eq? out 'results)
               (%%fail fmt-stx "the second argument of functional-type (column " (number->string column)
                       ") must be results"))
             (cond
              [(eq? in 'operands) (set! functional 'operands)]
              [(eq? in 'results)
               (%%fail fmt-stx "the first argument of functional-type (column " (number->string column)
                       ") must be operands or the one variadic operand")]
              [else
               (let ([entry (operand-name (cadr in))])
                 (unless (and entry (= (length operand-table) 1))
                   (%%fail fmt-stx "functional-type($" (cadr in) ", results) (column " (number->string column)
                           ") needs $" (cadr in) " to be the only operand; write operands otherwise"))
                 (set! functional 'variable))])
             (set! seen-operand-types (map car operand-table))
             (for-each (lambda (r)
                         (once! 'result r seen-result-types "the type of the result $" column)
                         (set! seen-result-types (cons r seen-result-types)))
                       result-names))]
          [(group)
           (let ([inner (cadr element)] [column (caddr element)])
             (when in-group
               (%%fail fmt-stx "a group (column " (number->string column) ") inside a group"))
             (when (null? inner)
               (%%fail fmt-stx "an empty group (column " (number->string column) ")"))
             (let ([first (car inner)])
               (unless (and (eq? (car first) 'variable)
                            (let ([entry (operand-name (cadr first))])
                              (and entry (eq? (cadr entry) ':optional))))
                 (%%fail fmt-stx "the first element of a group (column " (number->string column)
                         ") must be an optional operand"))
               (unless (caddr first)
                 (%%fail fmt-stx "the optional operand $" (cadr first) " (column " (number->string column)
                         ") that starts a group is its anchor: write $" (cadr first) "^")))
             (for-each (lambda (e)
                         (when (and (eq? (car e) 'variable) (operand-name (cadr e)) (not (eq? e (car inner))))
                           (%%fail fmt-stx "$" (cadr e) " (column " (number->string (cadddr e))
                                   ") is an operand inside a group; only its first operand may be"))
                         (when (and (eq? (car e) 'variable) (caddr e) (not (eq? e (car inner))))
                           (%%fail fmt-stx "$" (cadr e) "^ is not the first element of the group; "
                                   "the anchor is the first element in this version"))
                         (unless (memq (car e) '(literal variable type))
                           (%%fail fmt-stx "a group holds literals, variables and type directives only (column "
                                   (number->string (caddr element)) ")"))
                         (visit e #t))
                       inner)
             ;; an operand variable of the group has its type in the group
             (let ([in-group-vars (filter (lambda (e) (eq? (car e) 'variable)) inner)]
                   [in-group-types (filter (lambda (e) (and (eq? (car e) 'type) (pair? (cadr e)))) inner)])
               (for-each
                (lambda (v)
                  (when (operand-name (cadr v))
                    (unless (exists (lambda (t) (string=? (cadr (cadr t)) (cadr v))) in-group-types)
                      (%%fail fmt-stx "the type of $" (cadr v) " must be in the same group (column "
                              (number->string column) ")"))))
                in-group-vars)))]
          [else (%%fail fmt-stx "unsupported element")]))
      (for-each (lambda (e) (visit e #f)) elements)
      ;; Every operand, its type, every result type and attr-dict appear.
      (unless operands-directive
        (for-each (lambda (entry)
                    (unless (member (car entry) seen-operands)
                      (%%fail fmt-stx "the operand $" (car entry) " does not appear in the format")))
                  operand-table))
      (when (and operands-directive (not functional))
        (%%fail fmt-stx "the operands directive needs functional-type(operands, results) for the operand types"))
      (for-each (lambda (entry)
                  (unless (member (car entry) seen-operand-types)
                    (%%fail fmt-stx "the type of the operand $" (car entry) " does not appear in the format")))
                operand-table)
      ;; Every result type appears, or none does and the op infers them.
      (unless infer-results?
        (for-each (lambda (r)
                    (unless (member r seen-result-types)
                      (%%fail fmt-stx "the type of the result $" r
                              " does not appear in the format: write type($" r ") or type(results)")))
                  result-names))
      (unless attr-dict-seen
        (%%fail fmt-stx "attr-dict does not appear in the format"))
      (let ([flex (filter (lambda (e) (not (eq? (cadr e) ':required))) operand-table)])
        (when (> (length flex) 1)
          (%%fail fmt-stx "more than one optional or variadic operand needs operandSegmentSizes, "
                  "which a format does not know yet")))))

  ;; ── Parser ──────────────────────────────────────────────────────────────────

  (define (%%generate-parser elements operand-table result-names functional-kind infer-results?
                             attribute-types)
    (with-syntax ([P (car (generate-temporaries '(parser)))]
                  [S (car (generate-temporaries '(state)))])
      (let* ([n-operands (length operand-table)]
             [ops-ids   (generate-temporaries (map (lambda (e) 'ops) operand-table))]
             [type-ids  (generate-temporaries (map (lambda (e) 'type) operand-table))]
             [rtype-ids (generate-temporaries (map (lambda (r) 'rtype) result-names))]
             [all-ops   (car (generate-temporaries '(all-ops)))]
             [ft        (car (generate-temporaries '(ft)))]
             [operand-index (lambda (name) (caddr (assoc name operand-table)))]
             [result-index  (lambda (name)
                              (let loop ([rs result-names] [i 0])
                                (if (string=? (car rs) name) i (loop (cdr rs) (+ i 1)))))]
             [punct-parser (lambda (text) (cdr (assoc text punctuation-parsers)))])
        (define (parse-type-into id)
          (with-syntax ([id id] [P #'P])
            #'(let ([t (mlir::OpAsmParser::parseType P)])
                (and (not (eqv? t 0)) (begin (set! id t) #t)))))
        (define (step e in-group)
          (case (car e)
            [(literal)
             (let ([text (cadr e)])
               (cond
                [(assoc text punctuation-parsers)
                 (with-syntax ([f (punct-parser text)] [P #'P]) #'(f P))]
                [else (with-syntax ([kw text] [P #'P]) #'(mlir::OpAsmParser::parseKeyword P kw))]))]
            [(variable)
             (let ([name (cadr e)])
               (cond
                [(assoc name operand-table)
                 => (lambda (entry)
                      (let ([id (list-ref ops-ids (caddr entry))])
                        (with-syntax ([id id] [P #'P])
                          (case (cadr entry)
                            [(:required)
                             #'(let ([h (mlir::OpAsmParser::parseOperand P)])
                                 (and (not (eqv? h 0)) (begin (set! id h) #t)))]
                            [(:optional)
                             #'(begin (set! id (mlir::OpAsmParser::parseOptionalOperand P)) #t)]
                            [else
                             #'(let ([h (mlir::OpAsmParser::parseOperandList P -1)])
                                 (and (not (eqv? h 0)) (begin (set! id h) #t)))]))))]
                [(assoc name attribute-types)
                 ;; a buildable attribute type: the text may leave the type out
                 => (lambda (entry)
                      (with-syntax ([name name] [P #'P] [S #'S]
                                    [type (%%buildable-type-expr (cdr entry) #'P)])
                        #'(not (eqv? 0 (mlir::OpAsmParser::parseAttribute<Type> P S type name)))))]
                [else
                 (with-syntax ([name name] [P #'P] [S #'S])
                   #'(not (eqv? 0 (mlir::OpAsmParser::parseAttribute P S name))))]))]
            [(operands)
             (with-syntax ([id all-ops] [P #'P])
               #'(let ([h (mlir::OpAsmParser::parseOperandList P -1)])
                   (and (not (eqv? h 0)) (begin (set! id h) #t))))]
            [(attr-dict)
             (with-syntax ([P #'P] [S #'S]) #'(mlir::OpAsmParser::parseOptionalAttrDict P S))]
            [(type)
             (let ([arg (cadr e)])
               (cond
                [(eq? arg 'results)
                 (with-syntax ([(s ...)
                                (let loop ([ids rtype-ids] [first #t])
                                  (if (null? ids)
                                      '()
                                      (append (if first '() (list (with-syntax ([P #'P]) #'(mlir::OpAsmParser::parseComma P))))
                                              (list (parse-type-into (car ids)))
                                              (loop (cdr ids) #f))))])
                   #'(and s ...))]
                [(assoc (cadr arg) operand-table)
                 => (lambda (entry) (parse-type-into (list-ref type-ids (caddr entry))))]
                [else (parse-type-into (list-ref rtype-ids (result-index (cadr arg))))]))]
            [(functional-type)
             (with-syntax ([id ft] [P #'P])
               #'(let ([t (mlir::OpAsmParser::parseFunctionalType P)])
                   (and (not (eqv? t 0)) (begin (set! id t) #t))))]
            [(group)
             (let* ([inner (cadr e)]
                    [anchor (assoc (cadr (car inner)) operand-table)]
                    [id (list-ref ops-ids (caddr anchor))])
               (with-syntax ([id id] [P #'P]
                             [(rest ...) (map (lambda (x) (step x #t)) (cdr inner))])
                 #'(let ([h (mlir::OpAsmParser::parseOptionalOperand P)])
                     (if (eqv? h 0)
                         #t
                         (begin (set! id h) (and rest ... #t))))))]))
        (let* ([resolve-steps
                (case functional-kind
                  [(operands)
                   (list (with-syntax ([ops all-ops] [ft ft] [P #'P] [S #'S])
                           #'(mlir::OpAsmParser::resolveOperandsFunctional P ops ft S)))]
                  [(variable)
                   (list (with-syntax ([ops (car ops-ids)] [ft ft] [P #'P] [S #'S])
                           #'(mlir::OpAsmParser::resolveOperandsFunctional P ops ft S)))]
                  [else
                   (map (lambda (entry)
                          (with-syntax ([ops (list-ref ops-ids (caddr entry))]
                                        [type (list-ref type-ids (caddr entry))]
                                        [P #'P] [S #'S])
                            #'(or (eqv? ops 0) (mlir::OpAsmParser::resolveOperands P ops type S))))
                        operand-table)])]
               [result-steps
                (cond
                 [infer-results?
                  ;; No result type in the text: the op's InferTypeOpInterface answers them from the
                  ;; operands and attributes parsed so far.
                  (list (with-syntax ([S #'S] [P #'P])
                          #'(guard (c [#t (mlir::OpAsmParser::emitError
                                           P (string-append "cannot infer the result types: "
                                                            (call-with-string-output-port
                                                             (lambda (port) (display-condition c port)))))
                                          #f])
                              (let ([types (mlir::InferTypeOpInterface::inferReturnTypes<OperationState*> S)])
                                (cond
                                 [(not types)
                                  (mlir::OpAsmParser::emitError
                                   P "the op does not implement InferTypeOpInterface")
                                  #f]
                                 [else
                                  (for-each (lambda (type) (mlir::OperationState::addType S type)) types)
                                  #t])))))]
                 [functional-kind
                  (list (with-syntax ([ft ft] [n (length result-names)] [S #'S] [P #'P]
                                      [message (format "expected ~d result type(s) in the functional type"
                                                       (length result-names))])
                          #'(and (or (eqv? (mlir::FunctionType::getNumResults ft) n)
                                     (begin (mlir::OpAsmParser::emitError P message) #f))
                                 (let add ([i 0])
                                   (if (>= i n)
                                       #t
                                       (begin (mlir::OperationState::addType
                                               S (mlir::FunctionType::getResult ft i))
                                              (add (+ i 1))))))))]
                 [else
                  (map (lambda (id) (with-syntax ([id id] [S #'S])
                                      #'(begin (mlir::OperationState::addType S id) #t)))
                       rtype-ids)])])
          (with-syntax ([(ops ...) ops-ids]
                        [(type ...) type-ids]
                        [(rtype ...) rtype-ids]
                        [all-ops all-ops]
                        [ft ft]
                        [(s ...) (map (lambda (e) (step e #f)) elements)]
                        [(r ...) resolve-steps]
                        [(rs ...) result-steps])
            ;; The lists of operands that the parser answered are freed when the parse ends,
            ;; whether it succeeds, fails or raises an error: resolveOperands only reads them.
            #'(lambda (P S)
                (let ([ops 0] ... [type #f] ... [rtype #f] ... [all-ops 0] [ft #f])
                  (dynamic-wind
                      (lambda () #f)
                      (lambda () (and s ... r ... rs ... #t))
                      (lambda ()
                        (crest::OpAsmParser::freeOperands ops) ...
                        (crest::OpAsmParser::freeOperands all-ops))))))))))

  ;; ── Printer ─────────────────────────────────────────────────────────────────

  (define (%%space-before? text last-was-punctuation)
    (cond
     [(and (not (= (string-length text) 1)) (not (string=? text "->"))) #t]
     [last-was-punctuation (not (memv (string-ref text 0) (string->list ">)}],")))]
     [else (not (memv (string-ref text 0) (string->list "<>(){}[],")))]))

  (define (%%generate-printer elements operand-table attribute-vars result-names attribute-types)
    (with-syntax ([OP (car (generate-temporaries '(op)))]
                  [PR (car (generate-temporaries '(printer)))]
                  [NM (car (generate-temporaries '(name)))])
      (let* ([n (length operand-table)]
             [flex (%%flex-index operand-table)]
             [total #'(mlir::Operation::getNumOperands OP)]
             [start-expr
              (lambda (index)
                (cond
                 [(or (not flex) (<= index flex)) (datum->syntax #'OP index)]
                 [else (with-syntax ([total total] [k (- n index)]) #'(- total k))]))]
             [size-expr (with-syntax ([total total] [k (- n 1)]) #'(- total k))]
             [result-index (lambda (name)
                             (let loop ([rs result-names] [i 0])
                               (if (string=? (car rs) name) i (loop (cdr rs) (+ i 1)))))]
             [should-space #t] [last-punct #f])
        (define (emit-string s)
          (with-syntax ([PR #'PR] [s s]) #'(mlir::OpAsmPrinter::printString PR s)))
        (define (space-statement) (emit-string " "))
        (define (operand-value entry)
          (with-syntax ([OP #'OP] [i (start-expr (caddr entry))])
            #'(mlir::Operation::getOperand OP i)))
        ;; The spacing flags make generation order-dependent: left to right (map's order is unspecified).
        (define (gen-all es)
          (let loop ([es es] [acc '()])
            (if (null? es)
                (apply append (reverse acc))
                (let ([statements (gen (car es))])
                  (loop (cdr es) (cons statements acc))))))
        (define (gen e)
          (case (car e)
            [(literal)
             (let* ([text (cadr e)]
                    [pre (if (and should-space (%%space-before? text last-punct)) (list (space-statement)) '())])
               (set! should-space (or (not (= (string-length text) 1))
                                      (not (memv (string-ref text 0) (string->list "<({[")))))
               (set! last-punct (let ([c (string-ref text 0)]) (not (or (char=? c #\_) (char-alphabetic? c)))))
               (append pre (list (emit-string text))))]
            [(attr-dict)
             (set! last-punct #f)
             (list (if (null? attribute-vars)
                       (with-syntax ([PR #'PR] [OP #'OP]) #'(mlir::OpAsmPrinter::printOptionalAttrDict PR OP))
                       (with-syntax ([PR #'PR] [OP #'OP] [(a ...) attribute-vars])
                         #'(mlir::OpAsmPrinter::printOptionalAttrDict<ArrayRef<StringRef>> PR OP (list a ...)))))]
            [(group)
             (let* ([inner (cadr e)]
                    [anchor (assoc (cadr (car inner)) operand-table)]
                    [statements (gen-all inner)])
               (with-syntax ([(s ...) statements] [total total] [k (- n 1)])
                 (list #'(when (> total k) s ...))))]
            [else
             ;; a variable, operands or a type directive: a space unless after an opening punctuation
             (let ([pre (if (or should-space (not last-punct)) (list (space-statement)) '())])
               (set! last-punct #f)
               (set! should-space #t)
               (append pre (list (gen-value e))))]))
        (define (gen-value e)
          (case (car e)
            [(variable)
             (let ([name (cadr e)])
               (cond
                [(assoc name operand-table)
                 => (lambda (entry)
                      (case (cadr entry)
                        [(:required)
                         (with-syntax ([PR #'PR] [v (operand-value entry)])
                           #'(mlir::OpAsmPrinter::printOperand PR v))]
                        [else
                         (with-syntax ([PR #'PR] [OP #'OP] [start (start-expr (caddr entry))] [size size-expr])
                           #'(let ([s start])
                               (let print ([i s])
                                 (when (< i (+ s size))
                                   (when (> i s) (mlir::OpAsmPrinter::printString PR ", "))
                                   (mlir::OpAsmPrinter::printOperand PR (mlir::Operation::getOperand OP i))
                                   (print (+ i 1))))))]))]
                [(assoc name attribute-types)
                 ;; a buildable attribute type: the text leaves the type out
                 (with-syntax ([PR #'PR] [OP #'OP] [name name])
                   #'(mlir::OpAsmPrinter::printAttributeWithoutType PR (mlir::Operation::getAttr OP name)))]
                [else
                 (with-syntax ([PR #'PR] [OP #'OP] [name name])
                   #'(mlir::OpAsmPrinter::printAttribute PR (mlir::Operation::getAttr OP name)))]))]
            [(operands)
             (with-syntax ([PR #'PR] [OP #'OP]) #'(mlir::OpAsmPrinter::printOperands PR OP))]
            [(type)
             (let ([arg (cadr e)])
               (cond
                [(eq? arg 'results)
                 (with-syntax ([PR #'PR] [OP #'OP]) #'(mlir::OpAsmPrinter::printResultTypes PR OP))]
                [(assoc (cadr arg) operand-table)
                 => (lambda (entry)
                      (with-syntax ([PR #'PR] [v (operand-value entry)])
                        #'(mlir::OpAsmPrinter::printType PR (mlir::Value::getType v))))]
                [else
                 (with-syntax ([PR #'PR] [OP #'OP] [j (result-index (cadr arg))])
                   #'(mlir::OpAsmPrinter::printType PR (mlir::Value::getType (mlir::Operation::getResult OP j))))]))]
            [(functional-type)
             (with-syntax ([PR #'PR] [OP #'OP]) #'(mlir::OpAsmPrinter::printFunctionalType PR OP))]))
        (with-syntax ([(s ...) (gen-all elements)])
          #'(lambda (OP PR NM) s ... (void))))))

  ;; ── Entry point ─────────────────────────────────────────────────────────────

  ;; fmt-stx is the string syntax of the clause; returns (values parse-lambda print-lambda) syntax.
  ;; The type an attribute with :buildable-type has when the text leaves it out, built from the parser's
  ;; context (what `parser.getBuilder().getI64Type()` is in C++).
  (define (%%buildable-type-expr key parser-stx)
    (with-syntax ([P parser-stx])
      (case key
        [(:i8)    #'(mlir::IntegerType::get<i8>  (mlir::AsmParser::getContext P))]
        [(:i16)   #'(mlir::IntegerType::get<i16> (mlir::AsmParser::getContext P))]
        [(:i32)   #'(mlir::IntegerType::get<i32> (mlir::AsmParser::getContext P))]
        [(:i64)   #'(mlir::IntegerType::get<i64> (mlir::AsmParser::getContext P))]
        [(:index) #'(mlir::IndexType::get        (mlir::AsmParser::getContext P))]
        [(:f32)   #'(mlir::Float32Type::get      (mlir::AsmParser::getContext P))]
        [(:f64)   #'(mlir::Float64Type::get      (mlir::AsmParser::getContext P))])))

  ;; Whether a directive of the format gives the type of a result (type($r), type(results), functional-type).
  (define (%%result-types-appear? elements result-names)
    (exists (lambda (e)
              (case (car e)
                [(type) (let ([arg (cadr e)])
                          (or (eq? arg 'results)
                              (and (pair? arg) (member (cadr arg) result-names) #t)))]
                [(functional-type) #t]
                [(group) (%%result-types-appear? (cadr e) result-names)]
                [else #f]))
            elements))

  ;; implements-infer-type?: the op has mlir::InferTypeOpInterface in its :interfaces, so the format may
  ;; leave out all of its result types.
  (define (generate-assembly-format fmt-stx operands attributes results implements-infer-type?)
    (let ([str (syntax->datum fmt-stx)])
      (unless (string? str)
        (syntax-violation 'define-op ":assembly-format expects a string" fmt-stx))
      (let* ([elements        (%%parse-format fmt-stx (%%tokenize fmt-stx str))]
             [operand-table   (%%operand-table operands)]
             [attribute-names (%%field-names attributes attribute-field-name)]
             [optional-attribute-names
              (%%field-names (filter (lambda (f) (eq? (attribute-field-modifier f) ':optional)) attributes)
                             attribute-field-name)]
             [result-names    (%%field-names results result-field-name)]
             ;; (name . type keyword) of the attributes that have a :buildable-type
             [attribute-types (filter cdr (map cons attribute-names
                                               (map attribute-field-buildable-type attributes)))])
        (let ([infer-results? (and implements-infer-type?
                                   (pair? result-names)
                                   (not (%%result-types-appear? elements result-names)))])
          (%%check fmt-stx elements operand-table attribute-names optional-attribute-names result-names
                   infer-results?)
          (let* ([functional-kind
                  (let find ([es elements])
                    (cond
                     [(null? es) #f]
                     [(eq? (car (car es)) 'functional-type)
                      (if (eq? (cadr (car es)) 'operands) 'operands 'variable)]
                     [else (find (cdr es))]))]
                 [attribute-vars
                  (let collect ([es elements])
                    (apply append
                           (map (lambda (e)
                                  (cond
                                   [(and (eq? (car e) 'variable) (member (cadr e) attribute-names)) (list (cadr e))]
                                   [(eq? (car e) 'group) (collect (cadr e))]
                                   [else '()]))
                                es)))])
            (values (%%generate-parser elements operand-table result-names functional-kind infer-results?
                                       attribute-types)
                    (%%generate-printer elements operand-table attribute-vars result-names
                                        attribute-types)))))))
  )
