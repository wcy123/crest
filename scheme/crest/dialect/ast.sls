;; AST record types for define-dialect macro — imported at expand phase.
;; Separate library because define-record-type is phase-0; the transformer
;; runs at phase-1 and needs these accessible there.
(library (crest dialect ast)
  (export dialect-parse
          make-dialect-parse
          dialect-parse?
          dialect-parse-name
          dialect-parse-ops
          dialect-parse-cbs
          op-parse
          make-op-parse
          op-parse?
          op-parse-name
          op-parse-operands
          op-parse-attributes
          op-parse-results
          op-parse-op-cbs
          operand-field
          make-operand-field
          operand-field?
          operand-field-name
          operand-field-type
          operand-field-modifier)
  (import (chezscheme))

  ;; A single operand field declaration inside (define-op ... :operands (...)).
  ;;   name     — symbol e.g. 'input — used for accessor name generation
  ;;   type     — syntax: predicate (value) → bool — used in verify generation
  ;;              e.g. #'mlir::isa<RankedTensorType>? or #'(lambda (v) ...)
  ;;   modifier — :required (default), :optional, or :variadic
  ;;
  ;; modifier drives verify generation: :required → exact count check,
  ;; :optional → allows absence, :variadic → lower-bound only.
  (define-record-type operand-field
    (fields (immutable name     operand-field-name)
            (immutable type     operand-field-type)
            (immutable modifier operand-field-modifier)))

  ;; Result of parse-clauses.
  ;;   name — MLIR dialect namespace string e.g. "toy"
  ;;   ops  — list of op-parse records (reverse order; callers must reverse)
  ;;   cbs  — 12-slot vector of Scheme callback syntax or #f (CrestDialect slots):
  ;;            0  :initialize                    6  :materialize-constant
  ;;            1  :get-dependent-dialects        7  :get-canonicalization-patterns
  ;;            2  :parse-attribute               8  :verify-op-attr
  ;;            3  :print-attribute               9  :verify-region-arg-attr
  ;;            4  :parse-type                   10  :verify-region-result-attr
  ;;            5  :print-type                   11  :get-registered-interface-for-op
  (define-record-type dialect-parse
    (fields (immutable name dialect-parse-name)
            (immutable ops  dialect-parse-ops)
            (immutable cbs  dialect-parse-cbs)))

  ;; Result of parse-define-op.
  ;;   name       — op name syntax e.g. #'constant (prefix added by caller)
  ;;   operands   — ((name type :modifier) ...) datum list
  ;;   attributes — ((name type) ...) datum list
  ;;   results    — ((name type) ...) datum list
  ;;   op-cbs     — 7-slot vector of Scheme callback syntax or #f (CrestOp slots):
  ;;                  0  :verify                        (op) → bool
  ;;                  1  :verify-regions                (op) → bool
  ;;                  2  :parse                         (parser state) → bool
  ;;                  3  :print                         (op printer name) → void
  ;;                  4  :fold                          (op) → bool
  ;;                  5  :get-canonicalization-patterns (pattern-set) → void
  ;;                  6  :populate-default-attrs        (op-name attrs) → void
  (define-record-type op-parse
    (fields (immutable name       op-parse-name)
            (immutable operands   op-parse-operands)
            (immutable attributes op-parse-attributes)
            (immutable results    op-parse-results)
            (immutable op-cbs     op-parse-op-cbs))))
