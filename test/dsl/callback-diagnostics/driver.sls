;; scheme-mlir driver: a walk whose visitor raises an error. The scenario (argv 2) says which op it raises at, and whether
;; the visitor itself runs a second walk (C++ -> Scheme -> C++ -> Scheme).
;; The error is a diagnostic at the Scheme source of the visitor, and the visitor answers "interrupt" to MLIR: the walk
;; stops and answers interrupt to Scheme as a number (mlir::WalkResult::interrupt), nothing is raised in Scheme.
;; The scenario "no-context" runs the walk without (current-MLIRContext): there is no context to make the location
;; in, so the process ends with the text.
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef) (mlir IR Operation)
        (mlir Dialect Func IR FuncOps)
        (mlir Support WalkResult))

(define path (car (command-line-arguments)))
(define scenario (cadr (command-line-arguments)))

(define visited 0)

(define (raise-at target)
  (lambda (op)
    (set! visited (+ visited 1))
    (if (string=? (mlir::Operation::getName op) target)
        (error 'callback "boom")
        mlir::WalkResult::advance)))

(define (interrupted? result) (= result mlir::WalkResult::interrupt))

(define (run module)
  (cond
   [(or (string=? scenario "walk") (string=? scenario "no-context"))
    (let ([result (mlir::Operation::walk module (raise-at "test.b"))])
      (printf "visited: ~a\n" visited)
      (printf "interrupted: ~a\n" (interrupted? result)))]
   [(string=? scenario "nested")
    ;; the visitor of the outer walk runs an inner walk whose visitor raises
    (let ([outer
           (mlir::Operation::walk
            module
            (lambda (op)
              (when (string=? (mlir::Operation::getName op) "test.a")
                (let ([inner (mlir::Operation::walk op (lambda (nested) (error 'callback "boom")))])
                  (printf "inner interrupted: ~a\n" (interrupted? inner))))
              mlir::WalkResult::advance))])
      (printf "outer interrupted: ~a\n" (interrupted? outer)))]
   [else (error 'driver "unknown scenario" scenario)]))

(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (mlir::MLIRContext::getOrLoadDialect ctx "func")
    (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx path)
      (if (string=? scenario "no-context")
          (run module)
          (with-current-MLIRContext ctx (run module))))))
