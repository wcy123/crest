;; scheme-mlir driver: calls resolveOperands, resolveOperandsFunctional and freeOperands with a handle that
;; is 0, or is the wrong kind, and says what each answered. argv[1] names the case. A binding that is given
;; a handle it cannot use answers an error (Rule 20); it does not crash. Each case is a run of its own,
;; because a crash ends the process.
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext)
        (mlir IR BuiltinTypes)
        (mlir IR OpImplementation)
        (mlir Dialect Arith IR Arith))

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

;; The parser and the state are not 0 (1 is only a number: it is not read), the type is.
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
