#!r6rs
;; A rewrite pattern that makes a function with the bindings that take a rewriter: func.func (FuncOp::create), its entry
;; block (RewriterBase::createBlock), the insertion point at the end of that block (setInsertionPointToEnd) and func.return
;; (ReturnOp::create). It also asks the rewriter for its listener (OpBuilder::getListener). None of these was named by
;; another test. (OpBuilder::getContext is not here: (mlir IR Builders) does not export it.) The pattern replaces test.trigger by test.done.
(library (passes rewriter-creators)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext mlir::Operation::getLoc)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet mlir::RewriterBase::createBlock
                mlir::RewriterBase::setInsertionPointToEnd)
          (only (mlir IR Builders) mlir::OpBuilder::getListener)
          (only (mlir IR BuiltinTypes) mlir::IntegerType::get<i32> mlir::FunctionType::get)
          (only (mlir Dialect Func IR FuncOps) mlir::func::FuncOp::create mlir::func::FuncOp::getBody mlir::func::ReturnOp::create)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (crest))

  (define (%%say label value) (display label) (display ": ") (display value) (newline))

  (define (%%build-function rewriter op)
    (let* ([ctx (mlir::Operation::getContext op)]
           [loc (mlir::Operation::getLoc op)]
           [i32 (mlir::IntegerType::get<i32>)]
           [function (mlir::func::FuncOp::create rewriter loc "generated" (mlir::FunctionType::get ctx (list i32) '()))]
           [entry (mlir::RewriterBase::createBlock rewriter (mlir::func::FuncOp::getBody function) (list i32))])
      (%%say "the rewriter has a listener" (if (zero? (mlir::OpBuilder::getListener rewriter)) "no" "yes"))
      (mlir::RewriterBase::setInsertionPointToEnd rewriter entry)
      (mlir::func::ReturnOp::create rewriter loc)
      function))

  (define-rewrite-pattern (%%build op rewriter)
    :if-match
      %out = test.trigger ()
    :then-let
      ([!out-type (mlir::Value::getType %out)]
       [function (%%build-function rewriter op)])
    :rewrite %out :with
      result = test.done () -> !out-type)

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx :rewrite-patterns (("test.trigger" %%build 1)))
          (mlir::applyPatternsGreedily module-op patterns)))))
  ) ;; end library
