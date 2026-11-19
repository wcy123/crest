;; Toy compiler Ch7 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch7/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch7/toyc.sls <file>
;;          --emit=ast|--emit=mlir|--emit=mlir-affine|--emit=mlir-llvm|--emit=llvm|--emit=jit [--opt]
;;
;; Pipeline (superset of ch5):
;;   1. Inline + shape-inference + canonicalize+CSE (toy.func level)
;;   2. (affine+llvm) lower-to-affine
;;   3. (affine+llvm) canonicalize+CSE on func.func
;;   4. (affine+llvm+opt) loop-fusion + scalar-replacement on func.func
;;   5. (llvm) lower-to-llvm (toy.print → printf, all → LLVM dialect)
;;   6. (llvm) DIScopeForLLVMFuncOp pass
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
  (let* ([option   (parse-command-line (command-line-arguments))]
         [filename (let ([files (option "file")]) (if (null? files) "-" (car files)))]
         [action   (option "emit")]
         [opt?     (eq? (option "opt") 'present)])
    (set! %%input-type (string->symbol (or (option "x") "toy")))
    (cond
     [(equal? action "ast")         (%%dump-ast filename)]
     [(equal? action "mlir")        (%%dump-mlir filename opt? #f #f)]
     [(equal? action "mlir-affine") (%%dump-mlir filename opt? #t #f)]
     [(equal? action "mlir-llvm")   (%%dump-mlir filename opt? #t #t)]
     [(equal? action "llvm")        (%%dump-llvm filename opt?)]
     [(equal? action "jit")         (%%run-jit  filename opt?)])))

;; The command line, as the C++ toyc's cl::opts read it: the input file (default "-": standard input),
;; --emit=<action>, --opt and -x <toy|mlir>, in any order. -h shows the usage.
;; (rime command-line-options) reads it.
(define-command-line-options parse-command-line
  [:long "--emit" :choices ("ast" "mlir" "mlir-affine" "mlir-llvm" "llvm" "jit") :required :description "the kind of output"]
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
      ;; LEAK WARNING: the module belongs to nobody; with-mlir::OwningOpRef erases it when this scope ends.
      ;; A plain let never erased it, and neither did exit, which skips the cleanup (see %%quit).
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
      ;; LEAK WARNING: the module belongs to nobody; with-mlir::OwningOpRef erases it when this scope ends.
      ;; A plain let never erased it, and neither did exit, which skips the cleanup (see %%quit).
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
      ;; LEAK WARNING: the module belongs to nobody; with-mlir::OwningOpRef erases it when this scope ends.
      ;; A plain let never erased it, and neither did exit, which skips the cleanup (see %%quit).
      (with-mlir::OwningOpRef module-op (%%build-module filename ctx)
        (%%run-pipeline! module-op ctx opt? #t #t)
        (guard (e [(%%engine-error? e "mlir::ExecutionEngine::create")
                   (%%quit-with "Failed to create the execution engine" e)]
                  [(%%engine-error? e "mlir::ExecutionEngine::invoke")
                   (%%quit-with "JIT invocation failed" e)])
          (with-ExecutionEngine engine (module-op (if opt? 3 0))
            (mlir::ExecutionEngine::invoke engine "main")))))))

;; The execution engine answers an error that has the text of MLIR; say it and end with status 1.
;; The who of an error that a binding answers is a string (crest-foreign-procedure).
(define (%%engine-error? e who)
  (and (who-condition? e) (equal? (condition-who e) who)))

(define (%%quit-with message e)
  (display message (current-error-port))
  (display ": " (current-error-port))
  (display (condition-message e) (current-error-port))
  (newline (current-error-port))
  (%%quit 1))

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
