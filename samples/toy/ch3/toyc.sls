;; Toy compiler Ch3 — pass run by crest-opt.
;; Mirrors mlir/examples/toy/Ch3/toyc.cpp
;;
;; Arguments via environment:
;;   TOYC_FILE    input .toy source file or .mlir file
;;   TOYC_ACTION  ast | mlir  (default: none)
;;   TOYC_OPT     1 | true  — enable canonicalization passes (mirrors --opt)
;;
;; When TOYC_FILE ends in .mlir the file is parsed directly (mirrors Ch3's -x mlir).
;; When TOYC_OPT is set, the four canonicalization patterns run before dumping MLIR.
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

  ;; Force the toy dialect to load so its custom printers/parsers are
  ;; registered. allowUnregisteredDialects lets ops be created without loading
  ;; their dialect, so we call getOrLoadDialect explicitly after registration.
  (define (%%load-toy! ctx)
    (toy:register! ctx)
    (mlir::MLIRContext::getOrLoadDialect ctx "toy"))

  (define (%%dump-ast filename)
    (let ([module-ast (parse-input-file filename)])
      (unless module-ast (exit 1))
      (toy:dump module-ast)))

  ;; Load a .toy file through the AST parser + mlir-gen.
  (define (%%build-module-from-toy filename)
    (let ([module-ast (parse-input-file filename)])
      (unless module-ast (exit 1))
      (let* ([ctx       (mlir::MLIRContext::new)]
             [_         (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
             [_         (%%load-toy! ctx)]
             [module-op (mlir-gen ctx module-ast)])
        (unless module-op (exit 1))
        (values ctx module-op))))

  ;; Load a .mlir file directly via mlir::parseSourceFile (mirrors Ch3's -x mlir).
  (define (%%build-module-from-mlir filename)
    (let* ([ctx       (mlir::MLIRContext::new)]
           [_         (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
           [_         (%%load-toy! ctx)]
           [op        (mlir::parseSourceFile ctx filename)])
      (when (zero? op)
        (display (string-append "Failed to parse MLIR file: " filename "\n")
                 (current-error-port))
        (exit 1))
      ;; parseSourceFile returns the ModuleOp's Operation* directly
      (values ctx op)))

  (define (%%build-module filename)
    (if (let ([n (string-length filename)])
          (and (>= n 5)
               (string=? (substring filename (- n 5) n) ".mlir")))
        (%%build-module-from-mlir filename)
        (%%build-module-from-toy  filename)))

  ;; %%module-op returns the raw Operation* for either source type.
  (define (%%module-op->op m)
    (if (integer? m) m (mlir::ModuleOp::getOperation m)))

  (define (%%opt-enabled?)
    (let ([v (getenv "TOYC_OPT")])
      (and v (not (member v '("" "0" "false"))))))

  (define (%%dump-mlir filename)
    (let-values ([(ctx module-op) (%%build-module filename)])
      (let ([op (%%module-op->op module-op)])
        (when (%%opt-enabled?)
          (with-current-MLIRContext ctx
            (with-RewritePatternSet (patterns ctx)
              (toy:add-canonicalization-patterns! patterns)
              (mlir::applyPatternsGreedily op patterns))))
        (display (mlir::Operation::print op))
        (newline))))

  (define (run-pass _op)
    (let ([filename (getenv "TOYC_FILE")]
          [action   (getenv "TOYC_ACTION")])
      (unless filename
        (display "TOYC_FILE not set\n" (current-error-port))
        (exit 1))
      (cond
       [(equal? action "ast")  (%%dump-ast  filename)]
       [(equal? action "mlir") (%%dump-mlir filename)]
       [else
        (display "No action — set TOYC_ACTION=ast|mlir\n"
                 (current-error-port))])))
  )
