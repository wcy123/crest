;; scheme-mlir driver: the visitor of mlir::Operation::walk answers one of the WalkResult constants for each op, and the
;; walk answers one too. Counts the ops that the visitor was called with.
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef) (mlir IR Operation)
        (mlir Dialect Func IR FuncOps)
        (mlir Support WalkResult))

(define path (car (command-line-arguments)))

(define (count-walk module stop-at answer)
  (let* ([visited 0]
         [result (mlir::Operation::walk
                  module
                  (lambda (op)
                    (set! visited (+ visited 1))
                    (if (string=? (mlir::Operation::getName op) stop-at) answer mlir::WalkResult::advance)))])
    (list visited result)))

(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (mlir::MLIRContext::getOrLoadDialect ctx "func")
    (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx path)
      (printf "constants: ~a ~a ~a\n" mlir::WalkResult::interrupt mlir::WalkResult::advance mlir::WalkResult::skip)
      ;; post-order: test.inner, test.a, test.b, func.return, func.func, builtin.module
      (let ([advance (count-walk module "none" mlir::WalkResult::advance)])
        (printf "advance: visited ~a, answer is advance ~a\n" (car advance) (= (cadr advance) mlir::WalkResult::advance)))
      (let ([interrupt (count-walk module "test.inner" mlir::WalkResult::interrupt)])
        (printf "interrupt: visited ~a, answer is interrupt ~a\n" (car interrupt)
                (= (cadr interrupt) mlir::WalkResult::interrupt)))
      (let ([skip (count-walk module "test.b" mlir::WalkResult::skip)])
        (printf "skip: visited ~a, answer is advance ~a\n" (car skip) (= (cadr skip) mlir::WalkResult::advance))))))
