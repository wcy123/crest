;; scheme-mlir driver: calls bindings with a handle that is 0, or that is the wrong kind, and says what
;; each answered. argv[1] names the case. A binding that is given a handle it cannot use answers an error
;; (Rule 20); it does not crash. Each case is a run of its own, because a crash ends the process.
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR Value)
        (mlir IR OwningOpRef) (mlir IR Builders) (mlir IR BuiltinOps) (mlir IR Location)
        (mlir IR BuiltinTypes) (mlir IR BuiltinAttributes)
        (mlir IR OpImplementation)
        (mlir Dialect Arith IR Arith)
        (mlir Dialect Func IR FuncOps)
        (mlir Dialect SCF IR SCFOps)
        (mlir ExecutionEngine ExecutionEngine)
        (mlir Pass PassManager)
        (crest pass))

(define-pass (noop op) #t)

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

;; The handle of the parser or printer is 0.
(case-is "parse-operand"      (try (lambda () (mlir::OpAsmParser::parseOperand 0))))
(case-is "parse-colon"        (try (lambda () (mlir::OpAsmParser::parseColon 0))))
(case-is "parse-keyword"      (try (lambda () (mlir::OpAsmParser::parseKeyword 0 "x"))))
(case-is "parse-attribute"    (try (lambda () (mlir::OpAsmParser::parseAttribute 0 0 "a"))))
(case-is "print-string"       (try (lambda () (mlir::OpAsmPrinter::printString 0 "x"))))
(case-is "asm-print-type"     (try (lambda () (mlir::AsmPrinter::printType 0 0))))

;; The printer is not 0 (1 is only a number: it is not read), the value is.
(case-is "print-operand"      (try (lambda () (mlir::OpAsmPrinter::printOperand 1 0))))
;; The parser and the state are not 0, the type is.
(case-is "resolve-type"       (try (lambda () (mlir::OpAsmParser::resolveOperands 1 0 0 1))))

;; The list of operands is 0 (a parse that failed answers 0), or is another kind of handle.
(case-is "resolve-list-null"
         (in-context (lambda (ctx)
                       (try (lambda () (mlir::OpAsmParser::resolveOperands 1 0 (mlir::IntegerType::get<i32>) 1))))))
(case-is "resolve-list-wrong"
         (in-context (lambda (ctx)
                       (try (lambda () (mlir::OpAsmParser::resolveOperands 1 ctx (mlir::IntegerType::get<i32>) 1))))))
;; freeOperands accepts 0 (nothing), and refuses another kind of handle.
(case-is "free-null"  (try (lambda () (crest::OpAsmParser::freeOperands 0))))
(case-is "free-wrong"
         (in-context (lambda (ctx) (try (lambda () (crest::OpAsmParser::freeOperands ctx))))))
;; The type is not a function type.
(case-is "resolve-functional"
         (in-context (lambda (ctx)
                       (try (lambda () (mlir::OpAsmParser::resolveOperandsFunctional 1 0 (mlir::IntegerType::get<i32>) 1))))))

;; The execution engine, the pass manager.
(case-is "engine-null"        (try (lambda () (with-ExecutionEngine engine (0) 'unused))))
(case-is "engine-not-module"
         (in-context (lambda (ctx)
                       (let ([loc (mlir::UnknownLoc::get ctx)])
                         (with-mlir::OwningOpRef module (mlir::ModuleOp::create loc)
                           (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd (mlir::ModuleOp::getBody module))
                             (let* ([attr (mlir::FloatAttr::get<f64> 1.5)]
                                    [value (mlir::arith::ConstantOp::create<f64> builder loc attr)])
                               (try (lambda () (with-ExecutionEngine engine ((mlir::Value::getDefiningOp value)) 'unused))))))))))
(case-is "run-null"
         (in-context (lambda (ctx)
                       (with-PassManager pm (ctx)
                         ;; An empty pass manager never reads the module, so it has a pass.
                         (mlir::PassManager::addPass pm (noop))
                         (try (lambda () (mlir::PassManager::run! pm 0)))))))
(case-is "add-pass-null"
         (try (lambda () (mlir::OpPassManager::addPass 0 (noop)))))

;; Arith: a value or an attribute that is 0, or is not what the op needs.
(define (with-arith-builder body)
  (in-context (lambda (ctx)
                (let ([loc (mlir::UnknownLoc::get ctx)])
                  (with-mlir::OwningOpRef module (mlir::ModuleOp::create loc)
                    (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd (mlir::ModuleOp::getBody module))
                      (body ctx builder loc)))))))
(case-is "arith-add-null"
         (with-arith-builder (lambda (ctx builder loc)
                               (try (lambda () (mlir::arith::AddFOp::create builder loc 0 0))))))
(case-is "arith-constant-null"
         (with-arith-builder (lambda (ctx builder loc)
                               (try (lambda () (mlir::arith::ConstantOp::create<f64> builder loc 0))))))
(case-is "arith-constant-untyped"
         (with-arith-builder (lambda (ctx builder loc)
                               (try (lambda () (mlir::arith::ConstantOp::create<f64> builder loc (mlir::UnitAttr::get)))))))

;; The pointer is the wrong kind of object: a module is not a func.func, an integer type is not a function
;; type, and 0 is not an attribute.
(case-is "scf-forop-null"       (try (lambda () (mlir::scf::ForOp::getBody 0))))
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
