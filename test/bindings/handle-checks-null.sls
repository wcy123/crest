;; scheme-mlir driver: calls bindings with a pointer that is 0 and says what each answered. argv[1] names
;; the case. A binding that is given a pointer it cannot use answers an error (Rule 20); it does not
;; crash. Each case is a run of its own, because a crash ends the process.
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR Value)
        (mlir IR OwningOpRef) (mlir IR Builders) (mlir IR BuiltinOps) (mlir IR Location)
        (mlir IR BuiltinTypes) (mlir IR BuiltinAttributes)
        (mlir IR OpImplementation)
        (mlir Dialect Arith IR Arith)
        (mlir Dialect SCF IR SCFOps)
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

;; The pass manager.
(case-is "run-null"
         (in-context (lambda (ctx)
                       (with-PassManager pm (ctx)
                         ;; An empty pass manager never reads the module, so it has a pass.
                         (mlir::PassManager::addPass pm (noop))
                         (try (lambda () (mlir::PassManager::run! pm 0)))))))
(case-is "add-pass-null"
         (try (lambda () (mlir::OpPassManager::addPass 0 (noop)))))

;; Arith: a value that is 0.
(define (with-arith-builder body)
  (in-context (lambda (ctx)
                (let ([loc (mlir::UnknownLoc::get ctx)])
                  (with-mlir::OwningOpRef module (mlir::ModuleOp::create loc)
                    (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd (mlir::ModuleOp::getBody module))
                      (body ctx builder loc)))))))
(case-is "arith-add-null"
         (with-arith-builder (lambda (ctx builder loc)
                               (try (lambda () (mlir::arith::AddFOp::create builder loc 0 0))))))

;; The op is 0.
(case-is "scf-forop-null"       (try (lambda () (mlir::scf::ForOp::getBody 0))))
