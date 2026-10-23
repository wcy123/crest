;; Lexer for the Toy language.
;; Mirrors mlir/examples/toy/Ch1/include/toy/Lexer.h
(library (toy ch3 lexer)
  (export
    make-lexer-buffer
    lexer:cur-tok
    lexer:get-next-token!
    lexer:consume!
    lexer:id
    lexer:value
    lexer:last-loc
    lexer:line
    lexer:col
    ;; Token symbols
    tok-eof tok-return tok-var tok-def tok-identifier tok-number)
  (import (chezscheme)
          (toy ch3 ast))

  ;; Token values — keywords use symbols; punctuation uses characters.
  (define tok-eof        'tok-eof)
  (define tok-return     'tok-return)
  (define tok-var        'tok-var)
  (define tok-def        'tok-def)
  (define tok-identifier 'tok-identifier)
  (define tok-number     'tok-number)

  ;; Lexer state record — mirrors the Lexer class fields.
  (define-record-type toy-lexer
    (fields
     (immutable filename)
     (immutable buf)           ; source string
     (mutable   buf-pos)       ; current index into buf
     (mutable   cur-tok)       ; current token
     (mutable   last-loc)      ; location at start of cur-tok
     (mutable   id-str)        ; identifier string (when cur-tok = tok-identifier)
     (mutable   num-val)       ; numeric value    (when cur-tok = tok-number)
     (mutable   last-char)     ; lookahead character (char or eof-object)
     (mutable   line-num)      ; current line (1-based)
     (mutable   col)))         ; current column

  ;; Constructor — mirrors LexerBuffer(begin, end, filename)
  (define (make-lexer-buffer filename source)
    (make-toy-lexer filename source 0 tok-eof
                    (make-location filename 0 0)
                    "" 0.0 #\space 0 0))

  ;; Accessor aliases matching the C++ API
  (define (lexer:cur-tok  lex) (toy-lexer-cur-tok  lex))
  (define (lexer:id       lex) (toy-lexer-id-str   lex))
  (define (lexer:value    lex) (toy-lexer-num-val   lex))
  (define (lexer:last-loc lex) (toy-lexer-last-loc  lex))
  (define (lexer:line     lex) (toy-lexer-line-num  lex))
  (define (lexer:col      lex) (toy-lexer-col       lex))

  ;; -------------------------------------------------------------------------
  ;; getNextChar — mirrors Lexer::getNextChar()
  ;; -------------------------------------------------------------------------
  (define (%%get-next-char! lex)
    (let ([buf (toy-lexer-buf lex)]
          [pos (toy-lexer-buf-pos lex)])
      (if (>= pos (string-length buf))
          (begin
            (toy-lexer-last-char-set! lex (eof-object))
            (eof-object))
          (let ([ch (string-ref buf pos)])
            (toy-lexer-buf-pos-set! lex (+ pos 1))
            (toy-lexer-col-set! lex (+ (toy-lexer-col lex) 1))
            (when (char=? ch #\newline)
              (toy-lexer-line-num-set! lex (+ (toy-lexer-line-num lex) 1))
              (toy-lexer-col-set! lex 0))
            (toy-lexer-last-char-set! lex ch)
            ch))))

  ;; -------------------------------------------------------------------------
  ;; getTok — mirrors Lexer::getTok()
  ;; -------------------------------------------------------------------------
  (define (%%get-tok! lex)
    ;; Skip whitespace
    (let skip ()
      (let ([c (toy-lexer-last-char lex)])
        (when (and (char? c) (char-whitespace? c))
          (%%get-next-char! lex)
          (skip))))

    ;; Save location before reading token
    (toy-lexer-last-loc-set! lex
                             (make-location (toy-lexer-filename lex)
                                            (toy-lexer-line-num lex)
                                            (toy-lexer-col lex)))

    (let ([c (toy-lexer-last-char lex)])
      (cond
       ;; EOF
       [(eof-object? c) tok-eof]

       ;; Identifier: [a-zA-Z][a-zA-Z0-9_]*
       [(char-alphabetic? c)
        (let loop ([s (string c)])
          (%%get-next-char! lex)
          (let ([next (toy-lexer-last-char lex)])
            (if (and (char? next)
                     (or (char-alphabetic? next)
                         (char-numeric? next)
                         (char=? next #\_)))
                (loop (string-append s (string next)))
                (begin
                  (toy-lexer-id-str-set! lex s)
                  (cond
                   [(string=? s "return") tok-return]
                   [(string=? s "def")    tok-def]
                   [(string=? s "var")    tok-var]
                   [else                  tok-identifier])))))]

       ;; Number: [0-9.]+
       [(or (char-numeric? c) (char=? c #\.))
        (let loop ([s (string c)])
          (%%get-next-char! lex)
          (let ([next (toy-lexer-last-char lex)])
            (if (and (char? next)
                     (or (char-numeric? next) (char=? next #\.)))
                (loop (string-append s (string next)))
                (begin
                  (toy-lexer-num-val-set! lex (string->number s))
                  tok-number))))]

       ;; Comment: # until end of line
       [(char=? c #\#)
        (let skip-comment ()
          (%%get-next-char! lex)
          (let ([next (toy-lexer-last-char lex)])
            (unless (or (eof-object? next)
                        (char=? next #\newline)
                        (char=? next #\return))
              (skip-comment))))
        (if (eof-object? (toy-lexer-last-char lex))
            tok-eof
            (%%get-tok! lex))]

       ;; Any other character is returned as itself
       [else
        (let ([tok c])
          (%%get-next-char! lex)
          tok)])))

  ;; -------------------------------------------------------------------------
  ;; Public API — mirrors Lexer's public methods
  ;; -------------------------------------------------------------------------

  ;; getNextToken — advance and return the new current token
  (define (lexer:get-next-token! lex)
    (let ([tok (%%get-tok! lex)])
      (toy-lexer-cur-tok-set! lex tok)
      tok))

  ;; consume — assert current token matches, then advance
  (define (lexer:consume! lex expected)
    (unless (equal? (toy-lexer-cur-tok lex) expected)
      (error 'lexer:consume! "token mismatch" expected (toy-lexer-cur-tok lex)))
    (lexer:get-next-token! lex))
  )
