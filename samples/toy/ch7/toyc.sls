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
        (only (mlir support array-ref) with-CrestObject)
        (mlir IR DialectRegistry)
        (mlir IR MLIRContext)
        (mlir IR Operation)
        (mlir IR OperationSupport)
        (mlir IR BuiltinOps)
        (mlir IR PatternMatch)
        (mlir IR Value)
        (mlir IR BuiltinTypes)
        (mlir IR Block)
        (mlir IR Region)
        (mlir IR Builders)
        (mlir IR BuiltinAttributes)
        (only (mlir IR OpImplementation) mlir::StringAttr::getValue)
        (mlir Transforms GreedyPatternRewriteDriver)
        (mlir Pass PassManager)
        (mlir Transforms Passes)
        (mlir Transforms InliningUtils)
        (mlir Dialect Affine Transforms Passes)
        (mlir Dialect Affine IR AffineOps)
        (mlir Dialect Arith IR Arith)
        (mlir Dialect MemRef IR MemRef)
        (mlir Dialect Func IR FuncOps)
        (mlir Dialect SCF IR SCFDialect)
        (mlir Dialect ControlFlow IR ControlFlow)
        (mlir Dialect LLVMIR IR LLVMDialect)
        (mlir Dialect LLVMIR Transforms Passes)
        (mlir Target LLVMIR Export)
        (mlir ExecutionEngine ExecutionEngine)
        (toy ch7 parser)
        (toy ch7 ast)
        (toy ch7 toy)
        (toy ch7 mlir-gen)
        (toy ch7 combine)
        (toy ch7 lower-to-affine)
        (toy ch7 lower-to-llvm))

;; ---------------------------------------------------------------------------
;; Entry point
;; ---------------------------------------------------------------------------

(define (main)
  (let-values ([(filename action opt?) (%%parse-args (command-line-arguments))])
    (unless filename
      (display "Usage: toyc <file> [--emit=ast|--emit=mlir|--emit=mlir-affine|--emit=mlir-llvm|--emit=llvm|--emit=jit] [--opt]\n"
               (current-error-port))
      (exit 1))
    (cond
     [(equal? action "ast")        (%%dump-ast filename)]
     [(equal? action "mlir")       (%%dump-mlir filename opt? #f #f)]
     [(equal? action "mlir-affine")(%%dump-mlir filename opt? #t #f)]
     [(equal? action "mlir-llvm")  (%%dump-mlir filename opt? #t #t)]
     [(equal? action "llvm")       (%%dump-llvm filename opt?)]
     [(equal? action "jit")        (%%run-jit  filename opt?)]
     [else
      (display "No action — use --emit=ast, --emit=mlir, --emit=mlir-affine, --emit=mlir-llvm, --emit=llvm, or --emit=jit\n"
               (current-error-port))])))

(define (%%parse-args args)
  (let loop ([args args] [file #f] [action #f] [opt #f])
    (cond
     [(null? args) (values file action opt)]
     [(equal? (car args) "--emit=ast")         (loop (cdr args) file "ast" opt)]
     [(equal? (car args) "--emit=mlir")        (loop (cdr args) file "mlir" opt)]
     [(equal? (car args) "--emit=mlir-affine") (loop (cdr args) file "mlir-affine" opt)]
     [(equal? (car args) "--emit=mlir-llvm")   (loop (cdr args) file "mlir-llvm" opt)]
     [(equal? (car args) "--emit=llvm")        (loop (cdr args) file "llvm" opt)]
     [(equal? (car args) "--emit=jit")         (loop (cdr args) file "jit" opt)]
     [(equal? (car args) "--opt")              (loop (cdr args) file action #t)]
     [else                                     (loop (cdr args) (car args) action opt)])))

(define (%%dump-ast filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 1))
    (toy:dump module-ast)))

(define (%%dump-mlir filename opt? emit-affine? emit-llvm?)
  (with-DialectRegistry (reg)
    (mlir::DialectRegistry::insert reg "toy" "toy/ch6/toy")
    (mlir::affine::AffineDialect reg)
    (mlir::arith::ArithDialect   reg)
    (mlir::memref::MemRefDialect reg)
    (mlir::func::FuncDialect     reg)
    (mlir::scf::SCFDialect          reg)
    (mlir::cf::ControlFlowDialect   reg)
    (mlir::LLVM::LLVMDialect        reg)
    (mlir::LLVM::registerInlinerInterface reg)
    (with-MLIRContext (ctx reg)
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
  (with-DialectRegistry (reg)
    (mlir::DialectRegistry::insert reg "toy" "toy/ch6/toy")
    (mlir::affine::AffineDialect reg)
    (mlir::arith::ArithDialect   reg)
    (mlir::memref::MemRefDialect reg)
    (mlir::func::FuncDialect     reg)
    (mlir::scf::SCFDialect          reg)
    (mlir::cf::ControlFlowDialect   reg)
    (mlir::LLVM::LLVMDialect        reg)
    (mlir::LLVM::registerInlinerInterface reg)
    (with-MLIRContext (ctx reg)
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
        (display (mlir::translateModuleToLLVMIR module-op))
        (newline)))))

(define (%%run-jit filename opt?)
  (with-DialectRegistry (reg)
    (mlir::DialectRegistry::insert reg "toy" "toy/ch6/toy")
    (mlir::affine::AffineDialect reg)
    (mlir::arith::ArithDialect   reg)
    (mlir::memref::MemRefDialect reg)
    (mlir::func::FuncDialect     reg)
    (mlir::scf::SCFDialect          reg)
    (mlir::cf::ControlFlowDialect   reg)
    (mlir::LLVM::LLVMDialect        reg)
    (mlir::LLVM::registerInlinerInterface reg)
    (with-MLIRContext (ctx reg)
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
        (with-ExecutionEngine (engine module-op)
                              (when (not (zero? engine))
                                (let ([rc (mlir::ExecutionEngine::invoke engine "main")])
                                  (when (not (zero? rc))
                                    (display "JIT invocation failed\n" (current-error-port))
                                    (exit 1)))))))))

;; ---------------------------------------------------------------------------
;; Optimization pipeline
;; ---------------------------------------------------------------------------

(define (%%run-pipeline! module-op ctx opt? emit-affine? emit-llvm?)
  ;; Step 1: Inline + shape inference + canonicalize+CSE (toy.func level).
  ;; Ch7 adds one extra canonicalize pass in the toy.func nested PM.
  (%%inline-calls! module-op ctx)
  ;; Ch7: fold struct_access(struct_constant,...) before shape inference,
  ;; then erase dead struct_constant ops.
  (with-current-MLIRContext ctx
    (with-RewritePatternSet (patterns ctx)
      (toy:add-canonicalization-patterns! patterns)
      (mlir::applyPatternsGreedily module-op patterns)))
  (let ([dead-struct-constants '()])
    (mlir::Operation::walk module-op
                           (lambda (op)
                             (when (and (string=? (mlir::Operation::getName op)
                                                  "toy.struct_constant")
                                        (mlir::Operation::use_empty? op))
                               (set! dead-struct-constants
                                     (cons op dead-struct-constants)))))
    (for-each mlir::Operation::erase dead-struct-constants))
  (mlir::Operation::walk module-op
                         (lambda (op)
                           (when (string=? (mlir::Operation::getName op) "toy.func")
                             (%%run-shape-inference! op))))
  (with-current-MLIRContext ctx
    (with-RewritePatternSet (patterns ctx)
      (toy:add-canonicalization-patterns! patterns)
      (mlir::applyPatternsGreedily module-op patterns)))
  ;; Steps 2-4: Affine lowering (same as ch5).
  (when (or emit-affine? emit-llvm?)
    (%%toy-to-affine-lower! module-op ctx)
    (with-PassManager (pm ctx)
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
  ;; Step 5: LLVM lowering.
  (when emit-llvm?
    (%%toy-to-llvm-lower! module-op ctx)))

;; ---------------------------------------------------------------------------
;; Shape inference and inliner — identical to ch5
;; ---------------------------------------------------------------------------

(define (%%run-shape-inference! func-op)
  (define (%%ranked? type) (mlir::isa<RankedTensorType>? type))
  (define (%%all-operands-ranked? op)
    (let loop ([i 0] [n (mlir::Operation::getNumOperands op)])
      (or (>= i n)
          (and (%%ranked? (mlir::Value::getType (mlir::Operation::getOperand op i)))
               (loop (+ i 1) n)))))
  (define (%%infer-shape! op)
    (let ([name (mlir::Operation::getName op)])
      (cond
       [(or (string=? name "toy.add") (string=? name "toy.mul"))
        (mlir::Value::setType
         (mlir::Operation::getResult op 0)
         (mlir::Value::getType (mlir::Operation::getOperand op 0))) #t]
       [(string=? name "toy.cast")
        (mlir::Value::setType
         (mlir::Operation::getResult op 0)
         (mlir::Value::getType (mlir::Operation::getOperand op 0))) #t]
       [(string=? name "toy.transpose")
        (let* ([input-type (mlir::Value::getType (mlir::Operation::getOperand op 0))]
               [shape      (mlir::RankedTensorType::getShape input-type)]
               [rev-shape  (reverse shape)]
               [elem-type  (mlir::RankedTensorType::getElementType input-type)])
          (mlir::Value::setType
           (mlir::Operation::getResult op 0)
           (mlir::RankedTensorType::get rev-shape elem-type)) #t)]
       [else #f])))
  (define (%%needs-inference? op)
    (and (> (mlir::Operation::getNumResults op) 0)
         (not (%%ranked? (mlir::Value::getType (mlir::Operation::getResult op 0))))
         (let ([name (mlir::Operation::getName op)])
           (or (string=? name "toy.add") (string=? name "toy.mul")
               (string=? name "toy.cast") (string=? name "toy.transpose")))))
  (let loop ([changed #t])
    (when changed
      (let ([still-changed #f])
        (mlir::Operation::walk func-op
                               (lambda (op)
                                 (when (and (%%needs-inference? op)
                                            (%%all-operands-ranked? op))
                                   (%%infer-shape! op)
                                   (set! still-changed #t))))
        (loop still-changed))))
  (mlir::Operation::walk func-op
                         (lambda (op)
                           (when (%%needs-inference? op)
                             (mlir::Operation::emitError op
                                                         "shape inference failed")
                             (exit 1)))))

(define (%%inline-calls! module-op ctx)
  (let loop ()
    (let ([call #f])
      (mlir::Operation::walk module-op
                             (lambda (op)
                               (when (and (not call)
                                          (string=? (mlir::Operation::getName op) "toy.generic_call"))
                                 (set! call op))))
      (when call
        (%%inline-one! call module-op ctx)
        (loop))))
  (let ([to-erase '()])
    (mlir::Operation::walk module-op
                           (lambda (op)
                             (when (and (string=? (mlir::Operation::getName op) "toy.func")
                                        (%%private-func? op))
                               (set! to-erase (cons op to-erase)))))
    (for-each mlir::Operation::erase to-erase)))

(define (%%private-func? op)
  (let ([vis (mlir::Operation::getAttr op "sym_visibility")])
    (and vis (string=? (mlir::StringAttr::getValue vis) "private"))))

(define (%%find-func module-op name)
  (let ([found #f])
    (mlir::Operation::walk module-op
                           (lambda (op)
                             (when (and (not found)
                                        (string=? (mlir::Operation::getName op) "toy.func")
                                        (string=? (mlir::StringAttr::getValue
                                                   (mlir::Operation::getAttr op "sym_name"))
                                                  name))
                               (set! found op))))
    found))

(define (%%inline-one! call-op module-op ctx)
  (let* ([callee-name (mlir::StringAttr::getValue
                       (mlir::Operation::getAttr call-op "callee"))]
         [callee      (%%find-func module-op callee-name)]
         [entry-block (mlir::Region::front (mlir::Operation::getRegion callee 0))]
         [n-args      (mlir::Operation::getNumOperands call-op)]
         [val-map     (make-hashtable equal-hash equal?)])
    (do ([i 0 (+ i 1)]) ((= i n-args))
      (hashtable-set! val-map
                      (mlir::Block::getArgument entry-block i)
                      (mlir::Operation::getOperand call-op i)))
    (with-CrestObject (builder-obj (with-current-MLIRContext ctx
                                     (mlir::OpBuilder::atBlockEnd entry-block)))
      (let ([return-op #f])
        (mlir::Operation::walk callee
                               (lambda (op)
                                 (let ([name (mlir::Operation::getName op)])
                                   (cond
                                    [(string=? name "toy.func") (void)]
                                    [(string=? name "toy.return") (set! return-op op)]
                                    [else
                                     (mlir::OpBuilder::setInsertionPoint builder-obj call-op)
                                     (let* ([n-ops     (mlir::Operation::getNumOperands op)]
                                            [n-res     (mlir::Operation::getNumResults op)]
                                            [new-ops   (map (lambda (i)
                                                              (hashtable-ref val-map
                                                                             (mlir::Operation::getOperand op i)
                                                                             (mlir::Operation::getOperand op i)))
                                                            (iota n-ops))]
                                            [res-types (map (lambda (i)
                                                              (mlir::Value::getType
                                                               (mlir::Operation::getResult op i)))
                                                            (iota n-res))]
                                            [attrs     (%%collect-attrs op)]
                                            [new-op    (with-OperationState s ((mlir::Operation::getLoc op) name)
                                                         (for-each (lambda (v) (mlir::OperationState::addOperands s v)) new-ops)
                                                         (for-each (lambda (t) (mlir::OperationState::addTypes s t)) res-types)
                                                         (for-each (lambda (kv)
                                                                     (mlir::OperationState::addAttribute s (car kv) (cdr kv)))
                                                                   attrs)
                                                         (mlir::OpBuilder::create<OperationState> builder-obj s))])
                                       (do ([i 0 (+ i 1)]) ((= i n-res))
                                         (hashtable-set! val-map
                                                         (mlir::Operation::getResult op i)
                                                         (mlir::Operation::getResult new-op i))))]))))
        (when (and return-op (> (mlir::Operation::getNumOperands return-op) 0))
          (let* ([ret-val    (mlir::Operation::getOperand return-op 0)]
                 [mapped-val (hashtable-ref val-map ret-val ret-val)])
            (mlir::Value::replaceAllUsesWith
             (mlir::Operation::getResult call-op 0)
             mapped-val)))
        (mlir::Operation::erase call-op)))))

(define (%%collect-attrs op)
  (let ([result '()])
    (for-each
     (lambda (key)
       (let ([v (mlir::Operation::getAttr op key)])
         (when v (set! result (cons (cons key v) result)))))
     '("value" "callee" "sym_name" "function_type" "sym_visibility" "index"))
    result))

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
