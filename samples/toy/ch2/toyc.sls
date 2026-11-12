;; Toy compiler Ch2 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch2/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch2/toyc.sls <file.toy> [--emit=ast|--emit=mlir]
(import (chezscheme)
        (mlir IR DialectRegistry)
        (mlir IR MLIRContext)
        (mlir IR Operation)
        (mlir IR OwningOpRef)
        (mlir IR BuiltinOps)
        (toy ch2 parser)
        (toy ch2 ast)
        (toy ch2 toy)
        (toy ch2 mlir-gen))

(define %%input-type 'toy)

(define (main)
  (let-values ([(filename action opt? input-type) (%%parse-args (command-line-arguments))])
    (set! %%input-type input-type)
    (cond
     [(equal? action "ast")  (%%dump-ast  filename)]
     [(equal? action "mlir") (%%dump-mlir filename)]
     [else
      (display "No action specified (parsing only?), use -emit=<action>
"
               (current-error-port))
      (%%quit 255)])))

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
    (%%quit 5))
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (%%quit 1))
    (toy:dump module-ast)))

(define (%%dump-mlir filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (%%quit 6))
    (with-DialectRegistry reg ()
      (mlir::DialectRegistry::insert reg "toy" "toy/ch2/toy")
      (with-MLIRContext ctx (reg)
        (mlir::MLIRContext::getOrLoadDialect ctx "toy")
        ;; mlir-gen answers #f when it fails; erasing 0 does nothing.
        (with-mlir::OwningOpRef module-op (or (mlir-gen ctx module-ast) 0)
          (when (zero? module-op) (%%quit 1))
          (display (mlir::Operation::print (mlir::ModuleOp::getOperation module-op)))
          (newline))))))



;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it
;; (the context, the module), and raising does.
(define (%%quit code)
  (raise (list 'toyc-exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'toyc-exit)) (exit (cadr e))])
  (main))
