;; Asks Chez to import each raw constructor from its public library and prints "hidden" when the library does not
;; export it. Then uses each with- macro, which still reaches its private constructor.
(import (rnrs) (rnrs eval)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OperationSupport)
        (mlir IR Location) (mlir IR PatternMatch) (mlir Pass PassManager) (mlir ExecutionEngine ExecutionEngine))

(define (report library name)
  (display name)
  (display ": ")
  (display (guard (e [#t 'hidden])
             (environment `(only ,library ,name))
             'exported))
  (newline))

(report '(mlir IR MLIRContext) 'mlir::MLIRContext::new)
(report '(mlir IR DialectRegistry) 'mlir::DialectRegistry::new)
(report '(mlir Pass PassManager) 'mlir::PassManager::new)
(report '(mlir IR PatternMatch) 'mlir::RewritePatternSet::RewritePatternSet)
(report '(mlir IR OperationSupport) 'mlir::OperationState::create)
(report '(mlir ExecutionEngine ExecutionEngine) 'mlir::ExecutionEngine::create)

(with-DialectRegistry registry ()
  (with-MLIRContext ctx (registry)
    (with-PassManager manager (ctx) (display "with-PassManager: made") (newline))
    (with-RewritePatternSet patterns (ctx) (display "with-RewritePatternSet: made") (newline))
    (with-OperationState state ((mlir::UnknownLoc::get ctx) "test.op")
      (display "with-OperationState: made") (newline))))
