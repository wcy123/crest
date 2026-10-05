#!r6rs
(library (crest)
  (export define-conversion-pattern
          define-rewrite-pattern
          :if-match :then-let :rewrite :with :where
          :debug-parse :debug-validate :debug-analyze :debug-codegen :debug-matching
          = : -> :region :regions
          :any
          :current-op :attr
          :optional :variadic
          make-unbound-value unbound-value?)
  (import (except (rnrs) =)
          (crest internal keywords)  ;; Import keywords at run time for re-export
          (crest internal rewrite)               ;; with-mlir-ops used in generated :rewrite bodies
          (for (crest internal keywords) expand)  ;; Also at expand time
          (for (crest internal ast) expand)  ;; For AST predicates
          (for (crest internal codegen) expand)
          (for (only (crest internal codegen) make-unbound-value unbound-value?) expand))

  (define-syntax define-conversion-pattern
    (lambda (stx) (run-pipeline stx 'conversion)))

  ;; Like define-conversion-pattern but for OpRewritePattern:
  ;;   (define-rewrite-pattern (fname op rewriter) :if-match ... :rewrite ...)
  ;; No TypeConverter or converted-operands adaptor. All operand bindings
  ;; read from the op directly. Callback is (fname op rewriter) → #t/#f.
  (define-syntax define-rewrite-pattern
    (lambda (stx) (run-pipeline stx 'rewrite)))
)
