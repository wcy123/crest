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
      (with-mlir::OwningOpRef module-op (%%build-module filename ctx)
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
      (with-mlir::OwningOpRef module-op (%%build-module filename ctx)
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
      (with-mlir::OwningOpRef module-op (%%build-module filename ctx)
        (%%run-pipeline! module-op ctx opt? #t #t)
        (with-ExecutionEngine engine (module-op (if opt? 3 0))
          (when (zero? engine)
            (display "Failed to create the execution engine\n" (current-error-port))
            (%%quit 1))
          (let ([rc (mlir::ExecutionEngine::invoke engine "main")])
            (when (not (zero? rc))
              (display "JIT invocation failed\n" (current-error-port))
              (%%quit 1))))))))

;; ---------------------------------------------------------------------------
;; Optimization pipeline
;; ---------------------------------------------------------------------------

(define (%%run-passes! pm module-op)
  (unless (mlir::PassManager::run! pm module-op)
    (display "Optimization pipeline failed\n" (current-error-port))
    (%%quit 4)))

;; The pipeline of the C++ toyc, in one pass manager: the inliner, then shape inference, canonicalizer
;; and CSE nested on toy.func; for the lowerings the affine pass and canonicalizer + CSE (+ loop fusion
;; and scalar replacement with --opt) nested on func.func (and LLVM, with the DI scope pass, for --emit=mlir-llvm and later).
(define (%%run-pipeline! module-op ctx opt? emit-affine? emit-llvm?)
  (with-PassManager pm (ctx)
    (mlir::PassManager::addPass pm (mlir::createInlinerPass))
    (let ([func-pm (mlir::PassManager::nest pm "toy.func")])
      (mlir::OpPassManager::addPass func-pm (mlir::createCanonicalizerPass))
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
    (when emit-llvm?
      (mlir::PassManager::addPass pm (toy:lower-to-llvm-pass))
      (mlir::PassManager::addPass pm (mlir::LLVM::createDIScopeForLLVMFuncOpPass)))
    (%%run-passes! pm module-op)))

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
