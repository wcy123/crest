;; scheme-mlir driver: how long does it take to print one op that is nested in a module, for a small module and
;; for a large one? Prints the two times and their ratio. argv[1] and argv[2] are the two modules.
;; Printing with the default flags numbers every value of the whole module first, so the time grows with the
;; size of the module; it has to stay the same. The time is the CPU time of this process, the best of several
;; rounds that alternate between the two modules, so that the load of the machine does not decide the answer.
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef) (mlir IR Operation)
        (mlir Dialect Func IR FuncOps) (mlir Support WalkResult))

(define prints-per-round 500)
(define rounds 5)

;; The last op named t.op, which is inside the last function.
(define (find-op module)
  (let ([found 0])
    (mlir::Operation::walk
     module
     (lambda (op)
       (when (equal? (mlir::Operation::getName op) "t.op")
         (set! found op))
       #t mlir::WalkResult::advance))
    found))

(define (cpu-ms-of-prints op)
  (let ([start (cpu-time)])
    (do ([i 0 (+ i 1)]) ((= i prints-per-round)) (mlir::Operation::print op))
    (max 1 (- (cpu-time) start))))

(define args (command-line-arguments))

(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (mlir::MLIRContext::getOrLoadDialect ctx "func")
    (with-current-MLIRContext ctx
      (with-mlir::OwningOpRef small (mlir::parseSourceFile ctx (car args))
        (with-mlir::OwningOpRef large (mlir::parseSourceFile ctx (cadr args))
          (let ([small-op (find-op small)]
                [large-op (find-op large)]
                [best-small 1000000]
                [best-large 1000000])
            (do ([round 0 (+ round 1)]) ((= round rounds))
              (set! best-small (min best-small (cpu-ms-of-prints small-op)))
              (set! best-large (min best-large (cpu-ms-of-prints large-op))))
            (display "small module: ") (display best-small) (display " ms for ") (display prints-per-round) (display " prints") (newline)
            (display "large module: ") (display best-large) (display " ms for ") (display prints-per-round) (display " prints") (newline)
            (display "ratio: ") (display (/ (exact->inexact best-large) best-small)) (newline)))))))
