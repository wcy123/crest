;; Toy compiler Ch3 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch3/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch3/toyc.sls <file> [--emit=ast|--emit=mlir] [--opt]
;;
;; When the input file ends in .mlir it is parsed directly (mirrors Ch3's -x mlir).
;; --opt enables canonicalization passes before emitting MLIR.
(import (chezscheme)
        (rime command-line-options)
        (mlir IR DialectRegistry)
        (mlir IR MLIRContext)
        (mlir IR Operation)
        (mlir IR OwningOpRef)
        (mlir IR BuiltinOps)
        (toy ch3 parser)
        (toy ch3 ast)
        (toy ch3 toy)
        (toy ch3 mlir-gen)
        (mlir Pass PassManager)
        (mlir Transforms Passes))

(define %%input-type 'toy)

(define (main)
  (let-values ([(filename action opt? input-type) (%%parse-args (command-line-arguments))])
    (set! %%input-type input-type)
    (cond
     [(equal? action "ast")  (%%dump-ast  filename)]
     [(equal? action "mlir") (%%dump-mlir filename opt?)]
     [else
      (display "No action specified (parsing only?), use --emit=<action>
"
               (current-error-port))
      (%%quit 255)])))

;; The command line, as the C++ toyc's cl::opts read it: the input file (default "-": standard input),
;; --emit=<action> (also --emit <action>), -opt (also --opt) and -x <toy|mlir> (also -x=<...>,
;; --x=<...>). The options and the input file can come in any order, and -h shows the usage.
;; (rime command-line-options) reads it.
(define-command-line-options %%read-command-line
  [:long "--emit" :choices ("ast" "mlir") :description "the kind of output"]
  [:short "-opt"  :long "--opt"  :arity 0 :description "run the optimizer"]
  [:short "-x"    :long "--x"    :choices ("toy" "mlir") :description "the kind of input"])

;; Returns (values filename action opt? input-type): the input file, the action as a string or #f,
;; whether -opt is there, and the kind of input as a symbol.
;; A mistake in the command line is a message and the exit status 1.
(define (%%parse-args args)
  (let ([option (guard (e [(error? e)
                           (apply %%command-line-error (condition-message e) (condition-irritants e))])
                  (parameterize ([command-line '("toyc")])
                    (%%read-command-line args)))])
    (when (> (option 'number-of-positional-argument) 1)
      (%%command-line-error "too many input files"))
    (values (if (zero? (option 'number-of-positional-argument)) "-" (option 0))
            (option "--emit")
            (eq? (option "-opt") 'present)
            (string->symbol (or (option "-x") "toy")))))

(define (%%command-line-error message . irritants)
  (display "toyc: " (current-error-port))
  (display message (current-error-port))
  (for-each (lambda (irritant) (display " " (current-error-port)) (write irritant (current-error-port)))
            irritants)
  (newline (current-error-port))
  (%%quit 1))

(define (%%dump-ast filename)
  (when (eq? %%input-type 'mlir)
    (display "Can't dump a Toy AST when the input is MLIR\n" (current-error-port))
    (%%quit 5))
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (%%quit 1))
    (toy:dump module-ast)))

;; A pass manager nested on toy.func, as the C++ toyc builds it (pm.nest<toy::FuncOp>()); a failing pass
;; fails toyc (exit code 4).
(define (%%run-toy-func-passes! module-op ctx . make-passes)
  (with-PassManager pm (ctx)
    (let ([func-pm (mlir::PassManager::nest pm "toy.func")])
      (for-each (lambda (make-pass) (mlir::OpPassManager::addPass func-pm (make-pass)))
                make-passes))
    (unless (mlir::PassManager::run! pm module-op)
      (display "Optimization pipeline failed\n" (current-error-port))
      (%%quit 4))))

(define (%%dump-mlir filename opt?)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" "toy/ch3/toy")
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      ;; LEAK WARNING: the module belongs to nobody; with-mlir::OwningOpRef erases it when this scope ends.
      ;; A plain let never erased it, and neither did exit, which skips the cleanup (see %%quit).
      (with-mlir::OwningOpRef module-op (%%module-op->op (%%build-module filename ctx))
        (when opt?
          (%%run-toy-func-passes! module-op ctx mlir::createCanonicalizerPass))
        (display (mlir::Operation::print module-op))
        (newline)))))

(define (%%build-module filename ctx)
  (if (or (eq? %%input-type 'mlir)
          (let ([n (string-length filename)])
            (and (>= n 5) (string=? (substring filename (- n 5) n) ".mlir"))))
      (%%build-module-from-mlir filename ctx)
      (%%build-module-from-toy  filename ctx)))

(define (%%module-op->op m)
  (if (integer? m) m (mlir::ModuleOp::getOperation m)))



(define (%%build-module-from-toy filename ctx)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (%%quit 6))
    (let ([module-op (mlir-gen ctx module-ast)])
      (unless module-op (%%quit 1))
      module-op)))

(define (%%build-module-from-mlir filename ctx)
  (let ([op (mlir::parseSourceFile ctx filename)])
    (when (zero? op)
      (display (string-append "Error can't load file " filename "\n")
               (current-error-port))
      (%%quit 3))
    op))

;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it
;; (the context, the module), and raising does.
(define (%%quit code)
  (raise (list 'toyc-exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'toyc-exit)) (exit (cadr e))])
  (main))
