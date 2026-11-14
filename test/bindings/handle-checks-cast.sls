;; scheme-mlir driver: calls bindings with a pointer that is the wrong kind of object, or 0, and says what
;; each answered. argv[1] names the case. A binding that is given a pointer it cannot use answers an error
;; (Rule 20); it does not crash. Each case is a run of its own, because a crash ends the process.
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR Value)
        (mlir IR OwningOpRef) (mlir IR Builders) (mlir IR BuiltinOps) (mlir IR Location)
        (mlir IR BuiltinTypes) (mlir IR BuiltinAttributes)
        (mlir IR OpImplementation)
        (mlir Dialect Arith IR Arith)
        (mlir Dialect Func IR FuncOps)
        (mlir ExecutionEngine ExecutionEngine))

;; Prints "<who>: <why>" when the case raises the error of a binding, "no error" when it does not.
(define (try thunk)
  (guard (e [#t (display (if (who-condition? e) (condition-who e) "?"))
                (display ": ")
                (display (if (message-condition? e) (condition-message e) e))
                (newline)])
    (thunk)
    (display "no error") (newline)))

(define name (car (command-line-arguments)))

(define (in-context body)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert<mlir::arith::ArithDialect> reg)
    (with-MLIRContext ctx (reg)
      (with-current-MLIRContext ctx
        (mlir::MLIRContext::getOrLoadDialect ctx "arith")
        (body ctx)))))

(define-syntax case-is
  (syntax-rules ()
    [(_ label body ...) (when (string=? name label) body ...)]))

;; The execution engine: the module is 0, or is an op that is not a module.
(case-is "engine-null"        (try (lambda () (with-ExecutionEngine engine (0) 'unused))))
(case-is "engine-not-module"
         (in-context (lambda (ctx)
                       (let ([loc (mlir::UnknownLoc::get ctx)])
                         (with-mlir::OwningOpRef module (mlir::ModuleOp::create loc)
                           (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd (mlir::ModuleOp::getBody module))
                             (let* ([attr (mlir::FloatAttr::get<f64> 1.5)]
                                    [value (mlir::arith::ConstantOp::create<f64> builder loc attr)])
                               (try (lambda () (with-ExecutionEngine engine ((mlir::Value::getDefiningOp value)) 'unused))))))))))

;; Arith: an attribute that is 0, or is not what the op needs.
(define (with-arith-builder body)
  (in-context (lambda (ctx)
                (let ([loc (mlir::UnknownLoc::get ctx)])
                  (with-mlir::OwningOpRef module (mlir::ModuleOp::create loc)
                    (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd (mlir::ModuleOp::getBody module))
                      (body ctx builder loc)))))))
(case-is "arith-constant-null"
         (with-arith-builder (lambda (ctx builder loc)
                               (try (lambda () (mlir::arith::ConstantOp::create<f64> builder loc 0))))))
(case-is "arith-constant-untyped"
         (with-arith-builder (lambda (ctx builder loc)
                               (try (lambda () (mlir::arith::ConstantOp::create<f64> builder loc (mlir::UnitAttr::get)))))))

;; The pointer is the wrong kind of object: a module is not a func.func, an integer type is not a function
;; type, and 0 is not an attribute.
(case-is "string-attr-null"     (try (lambda () (mlir::StringAttr::getValue 0))))
(case-is "function-type-wrong"
         (in-context (lambda (ctx)
                       (try (lambda () (mlir::FunctionType::getNumInputs (mlir::IntegerType::get<i32>)))))))
(case-is "func-body-wrong"
         (in-context (lambda (ctx)
                       (with-mlir::OwningOpRef module (mlir::ModuleOp::create (mlir::UnknownLoc::get ctx))
                         (try (lambda () (mlir::func::FuncOp::getBody module)))))))
(case-is "module-body-wrong"
         (with-arith-builder (lambda (ctx builder loc)
                               (let ([value (mlir::arith::ConstantOp::create<f64> builder loc (mlir::FloatAttr::get<f64> 1.5))])
                                 (try (lambda () (mlir::ModuleOp::getBody (mlir::Value::getDefiningOp value))))))))
