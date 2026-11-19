;; Toy compiler Ch5 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch5/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch5/toyc.sls <file>
;;          [--emit=ast|--emit=mlir|--emit=mlir-affine] [--opt]
;;
;; --emit=mlir-affine pipeline (superset of ch4 --opt):
;;   1. Inline (MLIR's inliner pass, as in ch4)
;;   2. Shape inference (rewrite patterns, shape-inference.sls)
;;   3. Canonicalize (greedy rewrite, ch3/ch4 patterns)
;;   4. (affine) Scheme-level partial lowering toy → Affine+Arith+MemRef+Func
;;   5. (affine) Canonicalize + CSE on func.func (MLIR PassManager)
;;   6. (affine+opt) Loop fusion + affine scalar replacement (MLIR PassManager)
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
        (mlir IR BuiltinAttributes)
        (only (mlir IR OpImplementation) mlir::StringAttr::getValue)
        (mlir Pass PassManager)
        (mlir Transforms InliningUtils)
        (mlir Transforms Passes)
        (mlir Dialect Affine Transforms Passes)
        (mlir Dialect Affine IR AffineOps)
        (mlir Dialect Arith IR Arith)
        (mlir Dialect MemRef IR MemRef)
        (mlir Dialect Func IR FuncOps)
        (toy ch5 parser)
        (toy ch5 ast)
        (toy ch5 toy)
        (toy ch5 mlir-gen)
        (toy ch5 shape-inference)
        (toy ch5 lower-to-affine))

;; ---------------------------------------------------------------------------
;; Entry point
;; ---------------------------------------------------------------------------

(define %%input-type 'toy)

(define (main)
  (let-values ([(filename action opt? input-type) (%%parse-args (command-line-arguments))])
    (set! %%input-type input-type)
    (cond
     [(equal? action "ast")         (%%dump-ast filename)]
     [(equal? action "mlir")        (%%dump-mlir filename opt? #f)]
     [(equal? action "mlir-affine") (%%dump-mlir filename opt? #t)]
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
  [:long "--emit" :choices ("ast" "mlir" "mlir-affine") :description "the kind of output"]
  [:short "-opt"  :long "--opt"  :arity 0 :description "run the optimizer"]
  [:short "-x"    :long "--x"    :choices ("toy" "mlir") :description "the kind of input"]
  [:positional "file" :arity (0 1) :description "the input file, or - for standard input"])

;; Returns (values filename action opt? input-type): the input file, the action as a string or #f,
;; whether -opt is there, and the kind of input as a symbol.
;; A mistake in the command line is a message and the exit status 1.
(define (%%parse-args args)
  (let ([option (guard (e [(error? e)
                           (apply %%command-line-error (condition-message e) (condition-irritants e))])
                  (parameterize ([command-line '("toyc")])
                    (%%read-command-line args)))])
    (values (let ([files (option "file")]) (if (null? files) "-" (car files)))
            (option "emit")
            (eq? (option "opt") 'present)
            (string->symbol (or (option "x") "toy")))))

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

(define (%%dump-mlir filename opt? emit-affine?)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" "toy/ch5/toy")
    (mlir::DialectRegistry::insert<mlir::affine::AffineDialect> reg)
    (mlir::DialectRegistry::insert<mlir::arith::ArithDialect>  reg)
    (mlir::DialectRegistry::insert<mlir::memref::MemRefDialect> reg)
    (mlir::DialectRegistry::insert<mlir::func::FuncDialect>    reg)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      (mlir::MLIRContext::getOrLoadDialect ctx "affine")
      (mlir::MLIRContext::getOrLoadDialect ctx "arith")
      (mlir::MLIRContext::getOrLoadDialect ctx "func")
      (mlir::MLIRContext::getOrLoadDialect ctx "memref")
      ;; LEAK WARNING: the module belongs to nobody; with-mlir::OwningOpRef erases it when this scope ends.
      ;; A plain let never erased it, and neither did exit, which skips the cleanup (see %%quit).
      (with-mlir::OwningOpRef module-op (%%build-module filename ctx)
        (when (or opt? emit-affine?)
          (%%run-pipeline! module-op ctx opt? emit-affine?))
        (display (mlir::Operation::print module-op))
        (newline)))))

;; ---------------------------------------------------------------------------
;; Optimization pipeline
;; ---------------------------------------------------------------------------

(define (%%run-passes! pm module-op)
  (unless (mlir::PassManager::run! pm module-op)
    (display "Optimization pipeline failed\n" (current-error-port))
    (%%quit 4)))

;; The pipeline of the C++ toyc, in one pass manager: the inliner, then shape inference, canonicalizer
;; and CSE nested on toy.func; for the lowerings the affine pass and canonicalizer + CSE (+ loop fusion
;; and scalar replacement with --opt) nested on func.func.
(define (%%run-pipeline! module-op ctx opt? emit-affine?)
  (with-PassManager pm (ctx)
    (mlir::PassManager::addPass pm (mlir::createInlinerPass))
    (let ([func-pm (mlir::PassManager::nest pm "toy.func")])
      (mlir::OpPassManager::addPass func-pm (toy:shape-inference-pass))
      (mlir::OpPassManager::addPass func-pm (mlir::createCanonicalizerPass))
      (mlir::OpPassManager::addPass func-pm (mlir::createCSEPass)))
    (when emit-affine?
      (mlir::PassManager::addPass pm (toy:lower-to-affine-pass))
      (let ([func-pm (mlir::PassManager::nest pm "func.func")])
        (mlir::OpPassManager::addPass func-pm (mlir::createCanonicalizerPass))
        (mlir::OpPassManager::addPass func-pm (mlir::createCSEPass))
        (when opt?
          (mlir::OpPassManager::addPass func-pm (mlir::affine::createLoopFusionPass))
          (mlir::OpPassManager::addPass func-pm
                                        (mlir::affine::createAffineScalarReplacementPass)))))
    (%%run-passes! pm module-op)))

;; ---------------------------------------------------------------------------
;; Module loading
;; ---------------------------------------------------------------------------

(define (%%build-module filename ctx)
  (if (or (eq? %%input-type 'mlir)
          (let ([n (string-length filename)])
            (and (>= n 5) (string=? (substring filename (- n 5) n) ".mlir"))))
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
