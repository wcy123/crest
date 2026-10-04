#!r6rs
(library (crest)
  (export define-conversion-pattern
          define-rewrite-pattern
          :if-match :then-let :rewrite :with :where
          :debug-parse :debug-validate :debug-analyze :debug-codegen :debug-matching
          = : -> :region :regions
          :index :any
          :current-op :attr
          :optional :variadic
          make-unbound-value unbound-value?)
  (import (except (rnrs) =)
          (crest internal keywords)  ;; Import keywords at run time for re-export
          (mlir core ir)               ;; with-rewrite-builder etc. used in generated code
          (crest internal rewrite)               ;; with-mlir-ops used in generated :rewrite bodies
          (for (crest internal keywords) expand)  ;; Also at expand time
          (for (crest internal ast) expand)  ;; For AST predicates
          (for (crest internal parse) expand)
          (for (crest internal validate) expand)
          (for (crest internal analyze) expand)
          (for (crest internal codegen) expand)
          (for (only (crest internal codegen) make-unbound-value unbound-value?) expand))

  ;; Main macro: orchestrate 4 phases (waterfall style)
  ;; Phase 1: Parse -> AST
  ;; Phase 2: Validate -> checked AST (skipped if :debug-parse)
  ;; Phase 3: Analyze -> AST with bindings and actions (skipped if :debug-parse or :debug-validate)
  ;; Phase 4: Codegen -> final code (or debug output)
  (define-syntax define-conversion-pattern
    (lambda (stx)
      (let ([ast-rec (parse-to-ast stx)])
        (if (ast-pattern-expand-debug-parse? ast-rec)
            (generate-debug-ast ast-rec)
            (let ([validated (validate-ast ast-rec)])
              (if (ast-pattern-expand-debug-validate? validated)
                  (generate-debug-ast validated)
                  (let ([analyzed (analyze-ast validated)])
                    (if (ast-pattern-expand-debug-analyze? analyzed)
                        (generate-debug-ast analyzed)
                        (let ([real-code (generate-pattern-match-and-rewrite analyzed)])
                          (if (ast-pattern-expand-debug-codegen? analyzed)
                              (generate-debug-codegen analyzed real-code)
                              real-code))))))))))

  ;; Like define-conversion-pattern but for OpRewritePattern:
  ;;   (define-rewrite-pattern (fname op rewriter) :if-match ... :rewrite ...)
  ;; No TypeConverter or converted-operands adaptor. All operand bindings
  ;; read from the op directly. Callback is (fname op rewriter) → #t/#f.
  (define-syntax define-rewrite-pattern
    (lambda (stx)
      (let ([ast-rec (parse-to-ast stx 'rewrite)])
        (if (ast-pattern-expand-debug-parse? ast-rec)
            (generate-debug-ast ast-rec)
            (let ([validated (validate-ast ast-rec)])
              (if (ast-pattern-expand-debug-validate? validated)
                  (generate-debug-ast validated)
                  (let ([analyzed (analyze-ast validated)])
                    (if (ast-pattern-expand-debug-analyze? analyzed)
                        (generate-debug-ast analyzed)
                        (let ([real-code (generate-pattern-match-and-rewrite analyzed)])
                          (if (ast-pattern-expand-debug-codegen? analyzed)
                              (generate-debug-codegen analyzed real-code)
                              real-code))))))))))
)
