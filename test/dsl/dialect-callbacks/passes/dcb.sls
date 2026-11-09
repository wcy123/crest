#!r6rs
;; A dialect with the callbacks of the dialect itself. Each one says that it ran, on the output port.
;; Not here: :print-type and :print-attribute (a Scheme dialect has no type or attribute of its own
;; that MLIR would print through them, and no binding prints into a DialectAsmPrinter).
(library (passes dcb)
  (export dcb)
  (import (except (rnrs) =)
          (mlir IR Value)
          (mlir IR Operation)
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (mlir IR OpImplementation)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest dialect)
          (except (crest) :optional :variadic))

  (define (say . words)
    (let ([port (current-output-port)])
      (for-each (lambda (word) (display word port)) words)
      (newline port)
      (flush-output-port port)))

  (define-rewrite-pattern (%%neg-neg op rewriter)
    :if-match
      %inner = dcb.neg (%x)
      %out   = dcb.neg (%inner)
    :rewrite %out :with
      %x)

  (define-dialect dcb
    (:initialize (dialect) (say "dcb initialize"))
    (:get-dependent-dialects () (list "dcbdep"))
    (:parse-type (parser)
      (say "parse-type")
      (mlir::IntegerType::get<i32> (mlir::AsmParser::getContext parser)))
    (:parse-attribute (parser type)
      (say "parse-attribute")
      (mlir::StringAttr::get (mlir::AsmParser::getContext parser) "hello"))
    (:get-canonicalization-patterns (patterns)
      (say "get-canonicalization-patterns")
      (add-rewrite-pattern patterns "dcb.neg" %%neg-neg 1))
    (:verify-op-attr (op attr)
      (say "verify-op-attr " (mlir::Operation::getName op))
      (cond
       [(string=? (mlir::Operation::getName op) "dcb.bad")
        (mlir::Operation::emitError op "the attribute is not allowed")
        #f]
       [(string=? (mlir::Operation::getName op) "dcb.raises")
        (error 'verify-op-attr "the attribute is broken")]
       [else #t]))
    (:verify-region-arg-attr (op region-index arg-index attr)
      (say "verify-region-arg-attr " region-index " " arg-index)
      (if (eqv? arg-index 2)
          (begin (mlir::Operation::emitError op "the argument attribute is not allowed") #f)
          #t))
    (:verify-region-result-attr (op region-index result-index attr)
      (say "verify-region-result-attr " region-index " " result-index)
      #t)
    (define-op neg
      :operands ((x mlir::Value?))
      :results  ((out mlir::Value?)))
    (define-op make
      :results ((out mlir::Value?)))
    (define-op holder)
    (define-op bad)
    (define-op raises)))
