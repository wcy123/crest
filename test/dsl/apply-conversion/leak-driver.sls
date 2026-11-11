;; scheme-mlir driver: runs the conversion of passes/imperative many times, each on a context of its
;; own, and checks that the C functions made for its callbacks (patterns, legality checks, type
;; conversion) are released with the pattern set, the target and the type converter. They are code
;; objects that Chez keeps locked until C++ unlocks them: a leak shows as one per callback per run.
(import (chezscheme)
        (passes imperative)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR OwningOpRef)
        (mlir Dialect Func IR FuncOps))

(define (code-count)
  (collect 4 4)
  (let ([entry (assq 'code (object-counts))])
    (apply + (map cadr (cdr entry)))))

(define path (car (command-line-arguments)))

(define (once)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
      (mlir::MLIRContext::getOrLoadDialect ctx "func")
      (with-mlir::OwningOpRef<mlir::ModuleOp> module (mlir::parseSourceFile ctx path)
                                              (run-pass module)))))

(enable-object-counts #t)
(once)
(define before (code-count))
(define runs 100)
(do ([i 0 (+ i 1)]) ((= i runs)) (once))
(define growth (- (code-count) before))
;; A run makes five callables (three patterns, a legality check, a type conversion): a leak would be
;; five hundred.
(display (if (< growth runs) "released" (list "leaked" growth)))
(newline)
