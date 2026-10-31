;; Toy compiler Ch2 — top-level program for scheme-mlir.
;; Mirrors mlir/examples/toy/Ch2/toyc.cpp
;;
;; Usage: scheme-mlir samples/toy/ch2/toyc.sls <file.toy> [--emit=ast|--emit=mlir]
(import (chezscheme)
        (mlir IR DialectRegistry)
        (mlir IR MLIRContext)
        (mlir IR Operation)
        (mlir IR BuiltinOps)
        (toy ch2 parser)
        (toy ch2 ast)
        (toy ch2 toy)
        (toy ch2 mlir-gen))

(define (main)
  (let-values ([(filename action) (%%parse-args (command-line-arguments))])
    (unless filename
      (display "Usage: toyc <file.toy> [--emit=ast|--emit=mlir]\n"
               (current-error-port))
      (exit 1))
    (cond
     [(equal? action "ast")  (%%dump-ast  filename)]
     [(equal? action "mlir") (%%dump-mlir filename)]
     [else
      (display "No action — use --emit=ast or --emit=mlir\n"
               (current-error-port))])))

(define (%%parse-args args)
  (let loop ([args args] [file #f] [action #f])
    (cond
     [(null? args) (values file action)]
     [(member (car args) '("--emit=ast" "-emit=ast"))
      (loop (cdr args) file "ast")]
     [(member (car args) '("--emit=mlir" "-emit=mlir"))
      (loop (cdr args) file "mlir")]
     [else
      (loop (cdr args) (car args) action)])))

(define (%%dump-ast filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 1))
    (toy:dump module-ast)))

(define (%%dump-mlir filename)
  (let ([module-ast (parse-input-file filename)])
    (unless module-ast (exit 1))
    (let* ([ctx       (%%make-ctx)]
           [module-op (mlir-gen ctx module-ast)])
      (unless module-op (exit 1))
      (display (mlir::Operation::print (mlir::ModuleOp::getOperation module-op)))
      (newline))))

(define (%%make-ctx)
  (with-DialectRegistry (reg)
    (mlir::DialectRegistry::insert reg "toy" "toy/ch2/toy")
    (let ([ctx (mlir::MLIRContext::new reg)])
      (mlir::MLIRContext::getOrLoadDialect ctx "toy")
      ctx)))

(main)
