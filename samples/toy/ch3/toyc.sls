;; Toy compiler Ch3 — pass run by crest-opt.
;; Mirrors mlir/examples/toy/Ch3/toyc.cpp
;;
;; Arguments via environment:
;;   TOYC_FILE    input .toy file
;;   TOYC_ACTION  ast | mlir | mlir-opt  (default: none)
;;
;; mlir-opt runs the four canonicalization patterns before dumping MLIR,
;; mirroring Ch3's --opt flag + createCanonicalizerPass().
(library (toy ch3 toyc)
  (export run-pass)
  (import (chezscheme)
          (mlir IR MLIRContext)
          (mlir IR Operation)
          (mlir IR BuiltinOps)
          (mlir IR PatternMatch)
          (mlir Transforms GreedyPatternRewriteDriver)
          (toy ch3 parser)
          (toy ch3 ast)
          (toy ch3 toy)
          (toy ch3 mlir-gen)
          (toy ch3 combine))

  (define (%%dump-ast filename)
    (let ([module-ast (parse-input-file filename)])
      (unless module-ast (exit 1))
      (toy:dump module-ast)))

  (define (%%build-module filename)
    (let ([module-ast (parse-input-file filename)])
      (unless module-ast (exit 1))
      (let* ([ctx       (mlir::MLIRContext::new)]
             [_         (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
             [_         (toy:register! ctx)]
             [module-op (mlir-gen ctx module-ast)])
        (unless module-op (exit 1))
        (values ctx module-op))))

  (define (%%dump-mlir filename)
    (let-values ([(ctx module-op) (%%build-module filename)])
      (display (mlir::Operation::print (mlir::ModuleOp::getOperation module-op)))
      (newline)))

  (define (%%dump-mlir-opt filename)
    (let-values ([(ctx module-op) (%%build-module filename)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet (patterns ctx)
          (toy:add-canonicalization-patterns! patterns)
          (mlir::applyPatternsGreedily (mlir::ModuleOp::getOperation module-op) patterns)))
      (display (mlir::Operation::print (mlir::ModuleOp::getOperation module-op)))
      (newline)))

  (define (run-pass _op)
    (let ([filename (getenv "TOYC_FILE")]
          [action   (getenv "TOYC_ACTION")])
      (unless filename
        (display "TOYC_FILE not set\n" (current-error-port))
        (exit 1))
      (cond
       [(equal? action "ast")      (%%dump-ast      filename)]
       [(equal? action "mlir")     (%%dump-mlir     filename)]
       [(equal? action "mlir-opt") (%%dump-mlir-opt filename)]
       [else
        (display "No action — set TOYC_ACTION=ast|mlir|mlir-opt\n"
                 (current-error-port))])))
  )
