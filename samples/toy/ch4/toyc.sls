;; Toy compiler Ch4 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch4/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch4/toyc.sls <file> [--emit=ast|--emit=mlir] [--opt]
;;
;; Ch4 --opt pipeline:
;;   1. Inline toy.generic_call ops (eliminates private functions)
;;   2. Shape inference (rewrite patterns that resolve tensor<*xf64> to ranked types)
;;   3. Canonicalization (fold transpose/reshape pairs)
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
        (mlir Pass PassManager)
        (mlir Transforms Passes)
        (mlir Transforms InliningUtils)
        (mlir IR BuiltinAttributes)
        (only (mlir IR OpImplementation) mlir::StringAttr::getValue)
        (toy ch4 parser)
        (toy ch4 ast)
        (toy ch4 toy)
        (toy ch4 mlir-gen)
        (only (crest patterns) apply-patterns)
        (toy ch4 combine)
        (toy ch4 shape-inference))

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
     [(equal? (car args) "--emit=ast")
      (loop (cdr args) file "ast" opt)]
     [(equal? (car args) "--emit=mlir")
      (loop (cdr args) file "mlir" opt)]
     [(member (car args) '("--opt"))
      (loop (cdr args) file action #t)]
     [else
      (loop (cdr args) (car args) action opt)])))

(define (%%dump-ast filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 1))
    (toy:dump module-ast)))

(define (%%dump-mlir filename opt?)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" "toy/ch4/toy")
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      (let ([module-op (%%build-module filename ctx)])
        (when opt?
          (%%run-opt-pipeline! module-op ctx))
        (display (mlir::Operation::print module-op))
        (newline)))))

(define (%%run-opt-pipeline! module-op ctx)
  ;; Step 1: inline all toy.generic_call ops, eliminating private functions.
  (%%run-inliner! module-op ctx)
  ;; Step 2: shape inference — propagate concrete tensor shapes (patterns in shape-inference.sls).
  (with-current-MLIRContext ctx
    (apply-patterns module-op ctx :populate toy:add-shape-inference-patterns!))
  (toy:check-shapes-inferred! module-op)
  ;; Step 3: canonicalize (fold transpose/reshape patterns from combine.sls).
  (with-current-MLIRContext ctx
    (apply-patterns module-op ctx :populate toy:add-canonicalization-patterns!)))

(define (%%build-module filename ctx)
  (if (let ([n (string-length filename)])
        (and (>= n 5)
             (string=? (substring filename (- n 5) n) ".mlir")))
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

(main)
