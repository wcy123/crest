;; Toy compiler Ch6 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch6/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch6/toyc.sls <file>
;;          [--emit=ast|--emit=mlir|--emit=mlir-affine|--emit=mlir-llvm|--emit=llvm|--emit=jit] [--opt]
;;
;; Pipeline (superset of ch5):
;;   1. Inline + shape-inference + canonicalize+CSE (toy.func level)
;;   2. (affine+llvm) lower-to-affine
;;   3. (affine+llvm) canonicalize+CSE on func.func
;;   4. (affine+llvm+opt) loop-fusion + scalar-replacement on func.func
;;   5. (llvm) lower-to-llvm (toy.print → printf, all → LLVM dialect)
;;   6. (llvm) DIScopeForLLVMFuncOp pass
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
        (mlir Dialect SCF IR SCFDialect)
        (mlir Dialect ControlFlow IR ControlFlow)
        (mlir Dialect LLVMIR IR LLVMDialect)
        (mlir Dialect LLVMIR Transforms Passes)
        (mlir Conversion ReconcileUnrealizedCasts ReconcileUnrealizedCasts)
        (mlir Target LLVMIR Export)
        (mlir ExecutionEngine ExecutionEngine)
        (toy ch7 parser)
        (toy ch7 ast)
        (toy ch7 toy)
        (toy ch7 mlir-gen)
        (only (crest patterns) apply-patterns)
        (toy ch7 shape-inference)
        (toy ch7 lower-to-affine)
        (toy ch7 lower-to-llvm))

;; ---------------------------------------------------------------------------
;; Entry point
;; ---------------------------------------------------------------------------

(define %%input-type 'toy)

(define (main)
  (let-values ([(filename action opt? input-type) (%%parse-args (command-line-arguments))])
    (set! %%input-type input-type)
    (cond
     [(equal? action "ast")        (%%dump-ast filename)]
     [(equal? action "mlir")       (%%dump-mlir filename opt? #f #f)]
     [(equal? action "mlir-affine")(%%dump-mlir filename opt? #t #f)]
     [(equal? action "mlir-llvm")  (%%dump-mlir filename opt? #t #t)]
     [(equal? action "llvm")       (%%dump-llvm filename opt?)]
     [(equal? action "jit")        (%%run-jit  filename opt?)]
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

(define (%%dump-mlir filename opt? emit-affine? emit-llvm?)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" "toy/ch7/toy")
    (mlir::DialectRegistry::insert<mlir::affine::AffineDialect> reg)
    (mlir::DialectRegistry::insert<mlir::arith::ArithDialect>   reg)
    (mlir::DialectRegistry::insert<mlir::memref::MemRefDialect> reg)
    (mlir::DialectRegistry::insert<mlir::func::FuncDialect>     reg)
    (mlir::DialectRegistry::insert<mlir::scf::SCFDialect>          reg)
    (mlir::DialectRegistry::insert<mlir::cf::ControlFlowDialect>   reg)
    (mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>        reg)
    (mlir::LLVM::registerInlinerInterface reg)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      (mlir::MLIRContext::getOrLoadDialect ctx "affine")
      (mlir::MLIRContext::getOrLoadDialect ctx "arith")
      (mlir::MLIRContext::getOrLoadDialect ctx "func")
      (mlir::MLIRContext::getOrLoadDialect ctx "memref")
      (mlir::MLIRContext::getOrLoadDialect ctx "scf")
      (mlir::MLIRContext::getOrLoadDialect ctx "cf")
      (mlir::MLIRContext::getOrLoadDialect ctx "llvm")
      (let ([module-op (%%build-module filename ctx)])
        (when (or opt? emit-affine? emit-llvm?)
          (%%run-pipeline! module-op ctx opt? emit-affine? emit-llvm?))
        (display (mlir::Operation::print module-op))
        (newline)))))

(define (%%dump-llvm filename opt?)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" "toy/ch7/toy")
    (mlir::DialectRegistry::insert<mlir::affine::AffineDialect> reg)
    (mlir::DialectRegistry::insert<mlir::arith::ArithDialect>   reg)
    (mlir::DialectRegistry::insert<mlir::memref::MemRefDialect> reg)
    (mlir::DialectRegistry::insert<mlir::func::FuncDialect>     reg)
    (mlir::DialectRegistry::insert<mlir::scf::SCFDialect>          reg)
    (mlir::DialectRegistry::insert<mlir::cf::ControlFlowDialect>   reg)
    (mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>        reg)
    (mlir::LLVM::registerInlinerInterface reg)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      (mlir::MLIRContext::getOrLoadDialect ctx "affine")
      (mlir::MLIRContext::getOrLoadDialect ctx "arith")
      (mlir::MLIRContext::getOrLoadDialect ctx "func")
      (mlir::MLIRContext::getOrLoadDialect ctx "memref")
      (mlir::MLIRContext::getOrLoadDialect ctx "scf")
      (mlir::MLIRContext::getOrLoadDialect ctx "cf")
      (mlir::MLIRContext::getOrLoadDialect ctx "llvm")
      (let ([module-op (%%build-module filename ctx)])
        (%%run-pipeline! module-op ctx opt? #t #t)
        (display (mlir::translateModuleToLLVMIR module-op (if opt? 3 0)))
        (newline)))))

(define (%%run-jit filename opt?)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" "toy/ch7/toy")
    (mlir::DialectRegistry::insert<mlir::affine::AffineDialect> reg)
    (mlir::DialectRegistry::insert<mlir::arith::ArithDialect>   reg)
    (mlir::DialectRegistry::insert<mlir::memref::MemRefDialect> reg)
    (mlir::DialectRegistry::insert<mlir::func::FuncDialect>     reg)
    (mlir::DialectRegistry::insert<mlir::scf::SCFDialect>          reg)
    (mlir::DialectRegistry::insert<mlir::cf::ControlFlowDialect>   reg)
    (mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>        reg)
    (mlir::LLVM::registerInlinerInterface reg)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      (mlir::MLIRContext::getOrLoadDialect ctx "affine")
      (mlir::MLIRContext::getOrLoadDialect ctx "arith")
      (mlir::MLIRContext::getOrLoadDialect ctx "func")
      (mlir::MLIRContext::getOrLoadDialect ctx "memref")
      (mlir::MLIRContext::getOrLoadDialect ctx "scf")
      (mlir::MLIRContext::getOrLoadDialect ctx "cf")
      (mlir::MLIRContext::getOrLoadDialect ctx "llvm")
      (let ([module-op (%%build-module filename ctx)])
        (%%run-pipeline! module-op ctx opt? #t #t)
        (with-ExecutionEngine engine (module-op (if opt? 3 0))
          (when (zero? engine)
            (display "Failed to create the execution engine\n" (current-error-port))
            (exit 1))
          (let ([rc (mlir::ExecutionEngine::invoke engine "main")])
            (when (not (zero? rc))
              (display "JIT invocation failed\n" (current-error-port))
              (exit 1))))))))

;; ---------------------------------------------------------------------------
;; Optimization pipeline
;; ---------------------------------------------------------------------------

;; A failed lowering fails toyc, as the pass manager failing does in C++ (exit code 4).
(define (%%exit-unless-lowered ok?)
  (unless ok? (exit 4)))

;; A pass manager nested on toy.func, as the C++ toyc builds it (pm.nest<toy::FuncOp>()); a failing pass
;; fails toyc (exit code 4).
(define (%%run-toy-func-passes! module-op ctx . make-passes)
  (with-PassManager pm (ctx)
    (let ([func-pm (mlir::PassManager::nest pm "toy.func")])
      (for-each (lambda (make-pass) (mlir::OpPassManager::addPass func-pm (make-pass)))
                make-passes))
    (unless (mlir::PassManager::run! pm module-op)
      (display "Optimization pipeline failed\n" (current-error-port))
      (exit 4))))

(define (%%run-pipeline! module-op ctx opt? emit-affine? emit-llvm?)
  ;; Step 1: Inline + shape inference + canonicalize+CSE (toy.func level).
  ;; Ch7 adds one extra canonicalize pass in the toy.func nested PM.
  (%%run-inliner! module-op ctx)
  ;; Ch7 adds one canonicalization before shape inference: struct_access folds into the struct
  ;; constant, and the pure ops nothing uses any more disappear.
  (%%run-toy-func-passes! module-op ctx mlir::createCanonicalizerPass)
  (with-current-MLIRContext ctx
    (apply-patterns module-op ctx :populate toy:add-shape-inference-patterns!))
  (toy:check-shapes-inferred! module-op)
  (%%run-toy-func-passes! module-op ctx mlir::createCanonicalizerPass mlir::createCSEPass)
  ;; Steps 2-4: Affine lowering (same as ch5).
  (when (or emit-affine? emit-llvm?)
    (%%exit-unless-lowered (%%toy-to-affine-lower! module-op ctx))
    (with-PassManager pm (ctx)
      (let ([func-pm (mlir::PassManager::nest pm "func.func")])
        (mlir::OpPassManager::addPass func-pm (mlir::createCanonicalizerPass))
        (mlir::OpPassManager::addPass func-pm (mlir::createCSEPass)))
      (when opt?
        (let ([func-pm2 (mlir::PassManager::nest pm "func.func")])
          (mlir::OpPassManager::addPass func-pm2 (mlir::affine::createLoopFusionPass))
          (mlir::OpPassManager::addPass func-pm2
                                        (mlir::affine::createAffineScalarReplacementPass))))
      (unless (mlir::PassManager::run! pm module-op)
        (display "Post-affine pipeline failed\n" (current-error-port))
        (exit 1))))
  ;; Step 5: LLVM lowering + reconcile unrealized casts + DI scope.
  (when emit-llvm?
    (%%exit-unless-lowered (%%toy-to-llvm-lower! module-op ctx))
    (with-PassManager pm2 (ctx)
      (mlir::PassManager::addPass pm2 (mlir::createReconcileUnrealizedCastsPass))
      (mlir::PassManager::addPass pm2 (mlir::LLVM::createDIScopeForLLVMFuncOpPass))
      (unless (mlir::PassManager::run! pm2 module-op)
        (display "Post-LLVM pipeline failed\n" (current-error-port))
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

(define (%%build-module filename ctx)
  (if (or (eq? %%input-type 'mlir)
          (let ([n (string-length filename)])
            (and (>= n 5) (string=? (substring filename (- n 5) n) ".mlir"))))
      (%%build-module-from-mlir filename ctx)
      (%%build-module-from-toy  filename ctx)))

(define (%%build-module-from-toy filename ctx)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 6))
    (let ([module-op (mlir-gen ctx module-ast)])
      (unless module-op (exit 1))
      module-op)))

(define (%%build-module-from-mlir filename ctx)
  (let ([op (mlir::parseSourceFile ctx filename)])
    (when (zero? op)
      (display (string-append "Error can't load file " filename "\n")
               (current-error-port))
      (exit 3))
    op))

(main)
