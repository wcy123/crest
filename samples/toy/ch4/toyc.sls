;; Toy compiler Ch4 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch4/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch4/toyc.sls <file> --emit=ast|--emit=mlir [--opt]
;;
;; Ch4 --opt pipeline:
;;   1. Inline toy.generic_call ops (eliminates private functions)
;;   2. Shape inference (rewrite patterns that resolve tensor<*xf64> to ranked types)
;;   3. Canonicalization (fold transpose/reshape pairs)
(import (chezscheme)
        (rime command-line-options)
        (only (crest support CrestObject) with-CrestObject)
        (mlir IR DialectRegistry)
        (mlir IR MLIRContext)
        (mlir IR Operation)
        (mlir IR OwningOpRef)
        (mlir IR OperationSupport)
        (mlir IR BuiltinOps)
        (mlir IR Value)
        (mlir IR BuiltinTypes)
        (mlir IR Block)
        (mlir IR Region)
        (mlir IR Builders)
        (mlir Pass PassManager)
        (mlir Transforms Passes)
        (mlir Transforms InliningUtils)
        (mlir IR BuiltinAttributes)
        (only (mlir IR OpImplementation) mlir::StringAttr::getValue)
        (toy ch4 parser)
        (toy ch4 ast)
        (toy ch4 toy)
        (toy ch4 mlir-gen)
        (toy ch4 shape-inference))

(define %%input-type 'toy)

(define (main)
  (let* ([option   (parse-command-line (command-line-arguments))]
         [filename (let ([files (option "file")]) (if (null? files) "-" (car files)))]
         [action   (option "emit")]
         [opt?     (option "opt")])
    (set! %%input-type (string->symbol (option "x" "toy")))
    (cond
     [(equal? action "ast")  (%%dump-ast  filename)]
     [(equal? action "mlir") (%%dump-mlir filename opt?)])))

;; The command line, as the C++ toyc's cl::opts read it: the input file (default "-": standard input),
;; --emit=<action>, --opt and -x <toy|mlir>, in any order. -h shows the usage.
;; (rime command-line-options) reads it.
(define-command-line-options parse-command-line
  [:long "--emit" :choices ("ast" "mlir") :required :description "the kind of output"]
  [:long "--opt" :arity 0 :description "run the optimizer"]
  [:short "-x" :choices ("toy" "mlir") :description "the kind of input"]
  [:positional "file" :arity (0 1) :description "the input file, or - for standard input"])

(define (%%dump-ast filename)
  (when (eq? %%input-type 'mlir)
    (display "Can't dump a Toy AST when the input is MLIR\n" (current-error-port))
    (%%quit 5))
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (%%quit 1))
    (toy:dump module-ast)))

(define (%%dump-mlir filename opt?)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" "toy/ch4/toy")
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      ;; LEAK WARNING: the module belongs to nobody; with-mlir::OwningOpRef erases it when this scope ends.
      ;; A plain let never erased it, and neither did exit, which skips the cleanup (see %%quit).
      (with-mlir::OwningOpRef module-op (%%build-module filename ctx)
        (when opt?
          (%%run-opt-pipeline! module-op ctx))
        (display (mlir::Operation::print module-op))
        (newline)))))

(define (%%run-passes! pm module-op)
  (unless (mlir::PassManager::run! pm module-op)
    (display "Optimization pipeline failed\n" (current-error-port))
    (%%quit 4)))

(define (%%run-opt-pipeline! module-op ctx)
  ;; As the C++ toyc: the inliner, then shape inference, canonicalizer and CSE nested on toy.func.
  (with-PassManager pm (ctx)
    (mlir::PassManager::addPass pm (mlir::createInlinerPass))
    (let ([func-pm (mlir::PassManager::nest pm "toy.func")])
      (mlir::OpPassManager::addPass func-pm (toy:shape-inference-pass))
      (mlir::OpPassManager::addPass func-pm (mlir::createCanonicalizerPass))
      (mlir::OpPassManager::addPass func-pm (mlir::createCSEPass)))
    (%%run-passes! pm module-op)))

(define (%%build-module filename ctx)
  (if (or (eq? %%input-type 'mlir)
          (let ([n (string-length filename)])
            (and (>= n 5)
                 (string=? (substring filename (- n 5) n) ".mlir"))))
      (%%build-module-from-mlir filename ctx)
      (%%build-module-from-toy  filename ctx)))

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
;; (the context, the module, the execution engine), and raising does.
(define (%%quit code)
  (raise (list 'toyc-exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'toyc-exit)) (exit (cadr e))])
  (main))
