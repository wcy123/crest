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
        (only (mlir support CrestObject) with-CrestObject)
        (mlir IR DialectRegistry)
        (mlir IR MLIRContext)
        (mlir IR Operation)
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
        (only (crest patterns) apply-patterns)
        (toy ch5 combine)
        (toy ch5 shape-inference)
        (toy ch5 lower-to-affine))

;; ---------------------------------------------------------------------------
;; Entry point
;; ---------------------------------------------------------------------------

(define (main)
  (let-values ([(filename action opt?) (%%parse-args (command-line-arguments))])
    (unless filename
      (display "Usage: toyc <file> [--emit=ast|--emit=mlir|--emit=mlir-affine] [--opt]\n"
               (current-error-port))
      (exit 1))
    (cond
     [(equal? action "ast")         (%%dump-ast filename)]
     [(equal? action "mlir")        (%%dump-mlir filename opt? #f)]
     [(equal? action "mlir-affine") (%%dump-mlir filename opt? #t)]
     [else
      (display "No action — use --emit=ast, --emit=mlir, or --emit=mlir-affine\n"
               (current-error-port))])))

(define (%%parse-args args)
  (let loop ([args args] [file #f] [action #f] [opt #f])
    (cond
     [(null? args) (values file action opt)]
     [(equal? (car args) "--emit=ast")
      (loop (cdr args) file "ast" opt)]
     [(equal? (car args) "--emit=mlir")
      (loop (cdr args) file "mlir" opt)]
     [(equal? (car args) "--emit=mlir-affine")
      (loop (cdr args) file "mlir-affine" opt)]
     [(member (car args) '("--opt"))
      (loop (cdr args) file action #t)]
     [else
      (loop (cdr args) (car args) action opt)])))

(define (%%dump-ast filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 1))
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
      (let ([module-op (%%build-module filename ctx)])
        (when (or opt? emit-affine?)
          (%%run-pipeline! module-op ctx opt? emit-affine?))
        (display (mlir::Operation::print module-op))
        (newline)))))

;; ---------------------------------------------------------------------------
;; Optimization pipeline
;; ---------------------------------------------------------------------------

;; A failed lowering fails toyc, as the pass manager failing does in C++ (exit code 4).
(define (%%exit-unless-lowered ok?)
  (unless ok? (exit 4)))

(define (%%run-pipeline! module-op ctx opt? emit-affine?)
  ;; Step 1: Inline toy.generic_call ops (Scheme-level, same as ch4).
  (%%run-inliner! module-op ctx)
  ;; Step 2: Shape inference (patterns in shape-inference.sls).
  (with-current-MLIRContext ctx
    (apply-patterns module-op ctx :populate toy:add-shape-inference-patterns!))
  (toy:check-shapes-inferred! module-op)
  ;; Step 3: Canonicalize (fold transpose/reshape patterns).
  (with-current-MLIRContext ctx
    (apply-patterns module-op ctx :populate toy:add-canonicalization-patterns!))
  ;; Steps 4-6: Affine-specific lowering.
  (when emit-affine?
    ;; Step 4: Partial lowering to Affine+Arith+MemRef+Func.
    (%%exit-unless-lowered (%%toy-to-affine-lower! module-op ctx))
    ;; Steps 5-6: Post-lowering cleanup.
    (with-PassManager pm2 (ctx)
      (let ([func-pm (mlir::PassManager::nest pm2 "func.func")])
        (mlir::OpPassManager::addPass func-pm (mlir::createCanonicalizerPass))
        (mlir::OpPassManager::addPass func-pm (mlir::createCSEPass)))
      (when opt?
        (let ([func-pm2 (mlir::PassManager::nest pm2 "func.func")])
          (mlir::OpPassManager::addPass func-pm2 (mlir::affine::createLoopFusionPass))
          (mlir::OpPassManager::addPass func-pm2
                                        (mlir::affine::createAffineScalarReplacementPass))))
      (unless (mlir::PassManager::run! pm2 module-op)
        (display "Post-affine pipeline failed\n" (current-error-port))
        (exit 1)))))

;; ---------------------------------------------------------------------------
;; Inlining: MLIR's inliner pass, as in the C++ tutorial. toy.generic_call is a CallOpInterface,
;; toy.func is callable, the dialect's DialectInlinerInterface says inlining is legal, and the
;; pass erases the private callees that are dead afterwards.
;; ---------------------------------------------------------------------------

(define (%%run-inliner! module-op ctx)
  (with-PassManager pm (ctx)
    (mlir::PassManager::addPass pm (mlir::createInlinerPass))
    (unless (mlir::PassManager::run! pm module-op)
      (display "Inliner failed\n" (current-error-port))
      (exit 1))))

;; ---------------------------------------------------------------------------
;; Module loading
;; ---------------------------------------------------------------------------

(define (%%build-module filename ctx)
  (if (let ([n (string-length filename)])
        (and (>= n 5) (string=? (substring filename (- n 5) n) ".mlir")))
      (%%build-module-from-mlir filename ctx)
      (%%build-module-from-toy  filename ctx)))

(define (%%build-module-from-toy filename ctx)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 1))
    (let ([module-op (mlir-gen ctx module-ast)])
      (unless module-op (exit 1))
      module-op)))

(define (%%build-module-from-mlir filename ctx)
  (let ([op (mlir::parseSourceFile ctx filename)])
    (when (zero? op)
      (display (string-append "Failed to parse MLIR file: " filename "\n")
               (current-error-port))
      (exit 1))
    op))

(main)
