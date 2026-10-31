;; Toy compiler Ch3 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch3/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch3/toyc.sls <file> [--emit=ast|--emit=mlir] [--opt]
;;
;; When the input file ends in .mlir it is parsed directly (mirrors Ch3's -x mlir).
;; --opt enables canonicalization passes before emitting MLIR.
(import (chezscheme)
        (mlir IR DialectRegistry)
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
    (let ([op (%%module-op->op module-op)])
      (when opt?
        (with-current-MLIRContext ctx
          (with-RewritePatternSet (patterns ctx)
            (toy:add-canonicalization-patterns! patterns)
            (mlir::applyPatternsGreedily op patterns))))
      (display (mlir::Operation::print op))
      (newline))))

(define (%%build-module filename)
  (if (let ([n (string-length filename)])
        (and (>= n 5)
             (string=? (substring filename (- n 5) n) ".mlir")))
      (%%build-module-from-mlir filename)
      (%%build-module-from-toy  filename)))

(define (%%module-op->op m)
  (if (integer? m) m (mlir::ModuleOp::getOperation m)))

(define (%%make-ctx)
  (with-DialectRegistry (reg)
    (mlir::DialectRegistry::insertSchemeDialect reg "toy" "toy/ch3/toy")
    (let ([ctx (mlir::MLIRContext::new/registry reg)])
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      ctx)))

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

(main)
