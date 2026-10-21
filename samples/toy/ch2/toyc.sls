;; Toy compiler Ch2 — pass run by crest-opt.
;; Mirrors mlir/examples/toy/Ch2/toyc.cpp
;;
;; Arguments via environment:
;;   TOYC_FILE    input .toy file
;;   TOYC_ACTION  ast | mlir  (default: none)
(library (toy ch2 toyc)
  (export run-pass)
  (import (chezscheme)
          (mlir IR MLIRContext)
          (mlir IR Operation)
          (mlir IR BuiltinOps)
          (toy ch2 parser)
          (toy ch2 ast)
          (toy ch2 toy)
          (toy ch2 mlir-gen))

  (define (%%dump-ast filename)
    (let ([module-ast (parse-input-file filename)])
      (unless module-ast (exit 1))
      (toy:dump module-ast)))

  (define (%%dump-mlir filename)
    (let ([module-ast (parse-input-file filename)])
      (unless module-ast (exit 1))
      (let* ([ctx        (mlir::MLIRContext::new)]
             [_          (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
             [_          (toy:register! ctx)]
             [module-op  (mlir-gen ctx module-ast)])
        (unless module-op (exit 1))
        (display (mlir::Operation::print (mlir::ModuleOp::getOperation module-op)))
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
        (display "No action — set TOYC_ACTION=ast|mlir\n" (current-error-port))])))
  )
