;; scheme-mlir driver: bindings of operations, values, the pass manager and the log that no other test named:
;; moveBefore, getOpOperand, setType of a value, dump, emitWarning, emitError!, enableVerifier, and the log functions
;; trace and error. The module of argv[1] has the ops t.first and t.second; the second uses the result of the first.
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef) (mlir IR Operation) (mlir IR Value)
        (mlir IR BuiltinTypes) (mlir IR Attributes) (mlir IR BuiltinAttributes) (mlir Pass PassManager) (crest support logging) (mlir Support WalkResult))

(define (find module name)
  (let ([found 0])
    (mlir::Operation::walk module
                           (lambda (op) (when (equal? (mlir::Operation::getName op) name) (set! found op))
                                   #t mlir::WalkResult::advance))
    found))
(define (names module)
  (let ([result '()])
    (mlir::Operation::walk module
                           (lambda (op) (set! result (cons (mlir::Operation::getName op) result)) #t mlir::WalkResult::advance))
    (reverse result)))
(define (say label value) (display label) (display ": ") (display value) (newline))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (with-current-MLIRContext ctx
      (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
      (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car (command-line-arguments)))
        (let* ([first (find module "t.first")]
               [second (find module "t.second")])
          (say "the operand of t.second is the result of t.first"
               (if (= (mlir::Operation::getOpOperand second 0) (mlir::Operation::getResult first 0)) "yes" "no"))
          ;; t.first and t.second change places.
          (mlir::Operation::moveBefore second first)
          (say "order after the first move" (names module))
          (mlir::Operation::moveBefore first second)
          (say "order after the second move" (names module))
          ;; The type of a value is changed in place.
          (mlir::Value::setType (mlir::Operation::getResult first 0) (mlir::IntegerType::get<i16>))
          (say "type of the result after setType" (mlir::Attribute::print (mlir::TypeAttr::get (mlir::Value::getType (mlir::Operation::getResult first 0)))))
          (mlir::Operation::dump first)
          (mlir::Operation::emitWarning first "this is a warning")
          (mlir::Operation::emitError first "this is an error")
          (crest::logging::trace "this is a trace")
          (crest::logging::error "this is an error of the log"))
        (with-PassManager pm (ctx)
          (mlir::PassManager::enableVerifier pm #f)
          (mlir::PassManager::enableVerifier pm #t)
          (say "the pass manager runs with the verifier on" (if (mlir::PassManager::run! pm module) "yes" "no")))))))
