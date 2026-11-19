;; Toy compiler Ch3 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch3/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch3/toyc.sls <file> --emit=ast|--emit=mlir [--opt]
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
  (let* ([option   (parse-command-line (command-line-arguments))]
         [filename (let ([files (option "file")]) (if (null? files) "-" (car files)))]
         [action   (option "emit")]
         [opt?     (eq? (option "opt") 'present)])
    (set! %%input-type (string->symbol (or (option "x") "toy")))
    (cond
     [(equal? action "ast")  (%%dump-ast  filename)]
     [(equal? action "mlir") (%%dump-mlir filename opt?)])))

;; The command line, as the C++ toyc's cl::opts read it: the input file (default "-": standard input),
;; --emit=<action>, -opt and -x <toy|mlir>, in any order. -h shows the usage.
;; (rime command-line-options) reads it.
(define-command-line-options parse-command-line
  [:long "--emit" :choices ("ast" "mlir") :required :description "the kind of output"]
  [:short "-opt"  :long "--opt"  :arity 0 :description "run the optimizer"]
  [:short "-x"    :long "--x"    :choices ("toy" "mlir") :description "the kind of input"]
  [:positional "file" :arity (0 1) :description "the input file, or - for standard input"])

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
