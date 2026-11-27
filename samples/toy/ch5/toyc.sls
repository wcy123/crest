;; Toy compiler Ch5 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch5/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch5/toyc.sls <file>
;;          --emit=ast|--emit=mlir|--emit=mlir-affine [--opt]
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
  (let* ([option   (parse-or-exit parse-command-line (command-line-arguments))]
         [filename (let ([files (option "file")]) (if (null? files) "-" (car files)))]
         [action   (option "emit")]
         [opt?     (option "opt")])
    (set! %%input-type (string->symbol (option "x" "toy")))
    (cond
     [(equal? action "ast")         (%%dump-ast filename)]
     [(equal? action "mlir")        (%%dump-mlir filename opt? #f)]
     [(equal? action "mlir-affine") (%%dump-mlir filename opt? #t)])))

;; The command line, as the C++ toyc's cl::opts read it: the input file (default "-": standard input),
;; --emit=<action>, --opt and -x <toy|mlir>, in any order. -h shows the usage.
;; (rime command-line-options) reads it.
(define-command-line-options parse-command-line
  [:long "--emit" :choices ("ast" "mlir" "mlir-affine") :required :description "the kind of output"]
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

(define (%%run-passes! pm module-op)
  (unless (mlir::PassManager::run! pm module-op)
    (display "Optimization pipeline failed\n" (current-error-port))
    (%%quit 4)))

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
