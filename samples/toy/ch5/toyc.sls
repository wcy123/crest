;; Toy compiler Ch5 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch5/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch5/toyc.sls <file>
;;          [--emit=ast|--emit=mlir|--emit=mlir-affine] [--opt]
;;
;; --emit=mlir-affine pipeline (superset of ch4 --opt):
;;   1. Inline (mlir::createInlinerPass via MLIR PassManager)
;;   2. Shape inference (Scheme walk, per toy.func)
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
        (toy ch5 parser)
        (toy ch5 ast)
        (toy ch5 toy)
        (toy ch5 mlir-gen)
        (toy ch5 combine)
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
    (mlir::affine::AffineDialect reg)
    (mlir::arith::ArithDialect  reg)
    (mlir::memref::MemRefDialect reg)
    (mlir::func::FuncDialect    reg)
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

(define (%%run-pipeline! module-op ctx opt? emit-affine?)
  ;; Step 1: Inline toy.generic_call ops (Scheme-level, same as ch4).
  (%%inline-calls! module-op ctx)
  ;; Step 2: Shape inference per toy.func (Scheme walk).
  (mlir::Operation::walk module-op
                         (lambda (op)
                           (when (string=? (mlir::Operation::getName op) "toy.func")
                             (%%run-shape-inference! op))))
  ;; Step 3: Canonicalize (fold transpose/reshape patterns).
  (with-current-MLIRContext ctx
    (with-RewritePatternSet patterns (ctx)
      (toy:add-canonicalization-patterns! patterns)
      (mlir::applyPatternsGreedily module-op patterns)))
  ;; Steps 4-6: Affine-specific lowering.
  (when emit-affine?
    ;; Step 4: Partial lowering to Affine+Arith+MemRef+Func.
    (%%toy-to-affine-lower! module-op ctx)
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
;; Shape inference (same as ch4)
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
                                                         "shape inference failed: operand types not fully resolved")
                             (exit 1)))))

;; ---------------------------------------------------------------------------
;; Scheme-level inliner (mirrors ch4 approach; avoids MLIR terminator issues)
;; ---------------------------------------------------------------------------

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
    (with-OpBuilder builder-obj (with-current-MLIRContext ctx
                                  (mlir::OpBuilder::atBlockEnd entry-block))
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
     '("value" "callee" "sym_name" "function_type" "sym_visibility"))
    result))

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
