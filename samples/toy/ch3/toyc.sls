;; Toy compiler Ch3 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch3/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch3/toyc.sls <file> [--emit=ast|--emit=mlir] [--opt]
;;
;; When the input file ends in .mlir it is parsed directly (mirrors Ch3's -x mlir).
;; --opt enables canonicalization passes before emitting MLIR.
(import (chezscheme)
        (mlir IR DialectRegistry)
        (mlir IR MLIRContext)
        (mlir IR Operation)
        (mlir IR BuiltinOps)
        (toy ch3 parser)
        (toy ch3 ast)
        (toy ch3 toy)
        (toy ch3 mlir-gen)
        (only (crest patterns) apply-patterns)
        (toy ch3 combine))

(define %%input-type 'toy)

(define (main)
  (let-values ([(filename action opt? input-type) (%%parse-args (command-line-arguments))])
    (set! %%input-type input-type)
    (cond
     [(equal? action "ast")  (%%dump-ast  filename)]
     [(equal? action "mlir") (%%dump-mlir filename opt?)]
     [else
      (display "No action specified (parsing only?), use -emit=<action>
"
               (current-error-port))
      (exit 255)])))

;; The command line, as the C++ toyc's cl::opts read it: the input file (default "-": standard input),
;; -emit=<action> (also --emit=<action> and -emit <action>), -opt (also --opt) and -x <toy|mlir>
;; (also -x=<...>, --x=<...>).
(define (%%parse-args args)
  (let loop ([args args] [file "-"] [action #f] [opt #f] [input-type 'toy])
    (define (value-of arg prefixes)
      (let find ([ps prefixes])
        (cond
         [(null? ps) #f]
         [(and (> (string-length arg) (string-length (car ps)))
               (string=? (substring arg 0 (string-length (car ps))) (car ps)))
          (substring arg (string-length (car ps)) (string-length arg))]
         [else (find (cdr ps))])))
    (cond
     [(null? args) (values file action opt input-type)]
     [(value-of (car args) '("--emit=" "-emit="))
      => (lambda (a) (loop (cdr args) file a opt input-type))]
     [(and (member (car args) '("--emit" "-emit")) (pair? (cdr args)))
      (loop (cddr args) file (cadr args) opt input-type)]
     [(member (car args) '("--opt" "-opt"))
      (loop (cdr args) file action #t input-type)]
     [(value-of (car args) '("--x=" "-x="))
      => (lambda (t) (loop (cdr args) file action opt (string->symbol t)))]
     [(and (member (car args) '("--x" "-x")) (pair? (cdr args)))
      (loop (cddr args) file action opt (string->symbol (cadr args)))]
     [else
      (loop (cdr args) (car args) action opt input-type)])))

(define (%%dump-ast filename)
  (when (eq? %%input-type 'mlir)
    (display "Can't dump a Toy AST when the input is MLIR\n" (current-error-port))
    (exit 5))
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 1))
    (toy:dump module-ast)))

(define (%%dump-mlir filename opt?)
  (let-values ([(ctx module-op) (%%build-module filename)])
    (let ([op (%%module-op->op module-op)])
      (when opt?
        (with-current-MLIRContext ctx
          (apply-patterns op ctx :populate toy:add-canonicalization-patterns!)))
      (display (mlir::Operation::print op))
      (newline))))

(define (%%build-module filename)
  (if (or (eq? %%input-type 'mlir)
          (let ([n (string-length filename)])
            (and (>= n 5) (string=? (substring filename (- n 5) n) ".mlir"))))
      (%%build-module-from-mlir filename)
      (%%build-module-from-toy  filename)))

(define (%%module-op->op m)
  (if (integer? m) m (mlir::ModuleOp::getOperation m)))

(define (%%make-ctx)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" "toy/ch3/toy")
    (let ([ctx (mlir::MLIRContext::new reg)])
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      ctx)))

(define (%%build-module-from-toy filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 6))
    (let* ([ctx       (%%make-ctx)]
           [module-op (mlir-gen ctx module-ast)])
      (unless module-op (exit 1))
      (values ctx module-op))))

(define (%%build-module-from-mlir filename)
  (let* ([ctx (%%make-ctx)]
         [op  (mlir::parseSourceFile ctx filename)])
    (when (zero? op)
      (display (string-append "Error can't load file " filename "\n")
               (current-error-port))
      (exit 3))
    (values ctx op)))

(main)
