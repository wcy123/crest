;; Toy compiler Ch4 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch4/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch4/toyc.sls <file> [--emit=ast|--emit=mlir] [--opt]
;;
;; Ch4 --opt pipeline:
;;   1. Inline toy.generic_call ops (eliminates private functions)
;;   2. Shape inference (resolves tensor<*xf64> to concrete ranked types)
;;   3. Canonicalization (fold transpose/reshape pairs)
(import (chezscheme)
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
        (toy ch4 parser)
        (toy ch4 ast)
        (toy ch4 toy)
        (toy ch4 mlir-gen)
        (toy ch4 combine))

(define (main)
  (let-values ([(filename action opt?) (%%parse-args (command-line-arguments))])
    (unless filename
      (display "Usage: toyc <file> [--emit=ast|--emit=mlir] [--opt]\n"
               (current-error-port))
      (exit 1))
    (cond
     [(equal? action "ast")  (%%dump-ast  filename)]
     [(equal? action "mlir") (%%dump-mlir filename opt?)]
     [else
      (display "No action — use --emit=ast or --emit=mlir\n"
               (current-error-port))])))

(define (%%parse-args args)
  (let loop ([args args] [file #f] [action #f] [opt #f])
    (cond
     [(null? args) (values file action opt)]
     [(member (car args) '("--emit=ast" "-emit=ast"))
      (loop (cdr args) file "ast" opt)]
     [(member (car args) '("--emit=mlir" "-emit=mlir"))
      (loop (cdr args) file "mlir" opt)]
     [(member (car args) '("--opt" "-opt"))
      (loop (cdr args) file action #t)]
     [else
      (loop (cdr args) (car args) action opt)])))

(define (%%dump-ast filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 1))
    (toy:dump module-ast)))

(define (%%dump-mlir filename opt?)
  (let-values ([(ctx module-op) (%%build-module filename)])
    (when opt?
      (%%run-opt-pipeline! module-op ctx))
    (display (mlir::Operation::print module-op))
    (newline)))

(define (%%run-opt-pipeline! module-op ctx)
  ;; Step 1: inline all toy.generic_call ops, eliminating private functions.
  (%%inline-calls! module-op ctx)
  ;; Step 2: shape inference — propagate concrete tensor shapes per function.
  (mlir::Operation::walk module-op
                         (lambda (op)
                           (when (string=? (mlir::Operation::getName op) "toy.func")
                             (%%run-shape-inference! op))))
  ;; Step 3: canonicalize (fold transpose/reshape patterns from combine.sls).
  (with-current-MLIRContext ctx
    (with-RewritePatternSet (patterns ctx)
      (toy:add-canonicalization-patterns! patterns)
      (mlir::applyPatternsGreedily module-op patterns))))

;; Shape inference worklist pass — mirrors ShapeInferencePass.cpp.
;; Walks the function body; for ops with unranked results whose operand types
;; are all known (ranked), infers and sets the result type. Repeats until
;; fixed point.
(define (%%run-shape-inference! func-op)
  (define (%%ranked? type)
    (mlir::isa<RankedTensorType>? type))
  (define (%%all-operands-ranked? op)
    (let loop ([i 0] [n (mlir::Operation::getNumOperands op)])
      (or (>= i n)
          (and (%%ranked? (mlir::Value::getType (mlir::Operation::getOperand op i)))
               (loop (+ i 1) n)))))
  (define (%%infer-shape! op)
    (let ([name (mlir::Operation::getName op)])
      (cond
       ;; add/mul: result type = type of lhs operand
       [(or (string=? name "toy.add") (string=? name "toy.mul"))
        (mlir::Value::setType
         (mlir::Operation::getResult op 0)
         (mlir::Value::getType (mlir::Operation::getOperand op 0)))
        #t]
       ;; cast: result type = type of input
       [(string=? name "toy.cast")
        (mlir::Value::setType
         (mlir::Operation::getResult op 0)
         (mlir::Value::getType (mlir::Operation::getOperand op 0)))
        #t]
       ;; transpose: result type = input type with reversed shape
       [(string=? name "toy.transpose")
        (let* ([input-type (mlir::Value::getType (mlir::Operation::getOperand op 0))]
               [shape      (mlir::RankedTensorType::getShape input-type)]
               [rev-shape  (reverse shape)]
               [elem-type  (mlir::RankedTensorType::getElementType input-type)])
          (mlir::Value::setType
           (mlir::Operation::getResult op 0)
           (mlir::RankedTensorType::get rev-shape elem-type))
          #t)]
       [else #f])))
  ;; Collect ops with unranked results that we know how to infer.
  (define (%%needs-inference? op)
    (and (> (mlir::Operation::getNumResults op) 0)
         (not (%%ranked? (mlir::Value::getType (mlir::Operation::getResult op 0))))
         (let ([name (mlir::Operation::getName op)])
           (or (string=? name "toy.add")
               (string=? name "toy.mul")
               (string=? name "toy.cast")
               (string=? name "toy.transpose")))))
  ;; Fixed-point loop.
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
  ;; Report error if any op still has unranked results.
  (mlir::Operation::walk func-op
                         (lambda (op)
                           (when (%%needs-inference? op)
                             (mlir::Operation::emitError op
                                                         "shape inference failed: operand types not fully resolved")
                             (exit 1)))))

(define (%%build-module filename)
  (if (let ([n (string-length filename)])
        (and (>= n 5)
             (string=? (substring filename (- n 5) n) ".mlir")))
      (%%build-module-from-mlir filename)
      (%%build-module-from-toy  filename)))

(define (%%build-module-from-toy filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 1))
    (let* ([ctx       (%%make-ctx)]
           [module-op (mlir-gen ctx module-ast)])
      (unless module-op (exit 1))
      (values ctx module-op))))

(define (%%build-module-from-mlir filename)
  (let* ([ctx (%%make-ctx)]
         [op  (mlir::parseSourceFile ctx filename)])
    (when (zero? op)
      (display (string-append "Failed to parse MLIR file: " filename "\n")
               (current-error-port))
      (exit 1))
    (values ctx op)))

(define (%%make-ctx)
  (with-DialectRegistry (reg)
                        (mlir::DialectRegistry::insertSchemeDialect reg "toy" "toy/ch4/toy")
                        (let ([ctx (mlir::MLIRContext::new/registry reg)])
                          (mlir::MLIRContext::getOrLoadDialect ctx "toy")
                          ctx)))

;; ---------------------------------------------------------------------------
;; Scheme-level function inliner for toy.generic_call ops.
;; Replaces each call with a clone of the callee's body, substituting
;; block arguments with the actual call arguments.
;; ---------------------------------------------------------------------------

(define (%%inline-calls! module-op ctx)
  ;; Repeat until no more generic_call ops remain.
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
  ;; Remove private functions (they are now dead after inlining).
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
         ;; val-map: old value uptr → new value uptr
         [val-map     (make-hashtable equal-hash equal?)])
    ;; Map callee block args to actual call operands.
    (do ([i 0 (+ i 1)]) ((= i n-args))
      (hashtable-set! val-map
                      (mlir::Block::getArgument entry-block i)
                      (mlir::Operation::getOperand call-op i)))
    ;; Create a builder positioned just before the call op.
    (let* ([builder-obj (with-current-MLIRContext ctx
                          (mlir::OpBuilder::atBlockEnd entry-block))]
           [return-op #f])
      ;; Walk callee body, cloning each op before the call.
      (mlir::Operation::walk callee
                             (lambda (op)
                               (let ([name (mlir::Operation::getName op)])
                                 (cond
                                  ;; Skip the func op itself and the entry block (walk visits them).
                                  [(string=? name "toy.func") (void)]
                                  [(string=? name "toy.return")
                                   (set! return-op op)]
                                  [else
                                   ;; Clone op before call-op: set builder insertion point.
                                   (mlir::OpBuilder::setInsertionPoint builder-obj call-op)
                                   (let* ([n-ops     (mlir::Operation::getNumOperands op)]
                                          [n-res     (mlir::Operation::getNumResults op)]
                                          [new-ops   (map (lambda (i)
                                                            (let ([old (mlir::Operation::getOperand op i)])
                                                              (hashtable-ref val-map old old)))
                                                          (iota n-ops))]
                                          [res-types (map (lambda (i)
                                                            (mlir::Value::getType
                                                             (mlir::Operation::getResult op i)))
                                                          (iota n-res))]
                                          [attrs     (%%collect-attrs op)]
                                          [new-op    (with-OperationState (s (mlir::Operation::getLoc op) name)
                                                                          (for-each (lambda (v) (mlir::OperationState::addOperands s v)) new-ops)
                                                                          (for-each (lambda (t) (mlir::OperationState::addTypes s t)) res-types)
                                                                          (for-each (lambda (kv)
                                                                                      (mlir::OperationState::addAttribute s (car kv) (cdr kv)))
                                                                                    attrs)
                                                                          (mlir::OpBuilder::create<OperationState> builder-obj s))])
                                     ;; Map old results to new results.
                                     (do ([i 0 (+ i 1)]) ((= i n-res))
                                       (hashtable-set! val-map
                                                       (mlir::Operation::getResult op i)
                                                       (mlir::Operation::getResult new-op i))))]))))
      ;; Replace call result with the (mapped) return operand.
      (when (and return-op (> (mlir::Operation::getNumOperands return-op) 0))
        (let* ([ret-val     (mlir::Operation::getOperand return-op 0)]
               [mapped-val  (hashtable-ref val-map ret-val ret-val)])
          (mlir::Value::replaceAllUsesWith
           (mlir::Operation::getResult call-op 0)
           mapped-val)))
      (mlir::Operation::erase call-op))))

;; Collect op attributes as an alist of (name-string . attr-uptr).
;; Reads known attribute keys: "value" (constant), "callee".
(define (%%collect-attrs op)
  (let ([result '()])
    (for-each
     (lambda (key)
       (let ([v (mlir::Operation::getAttr op key)])
         (when v (set! result (cons (cons key v) result)))))
     '("value" "callee" "sym_name" "function_type" "sym_visibility"))
    result))

(main)
