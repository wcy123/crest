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
          dialect-parse-dialect-ifaces
          op-parse
          make-op-parse
          op-parse?
          op-parse-name
          op-parse-operands
          op-parse-attributes
          op-parse-results
          op-parse-op-cbs
          op-parse-interfaces
          operand-field
          make-operand-field
          operand-field?
          operand-field-name
          operand-field-type
          operand-field-modifier
          attribute-field
          make-attribute-field
          attribute-field?
          attribute-field-name
          attribute-field-type
          attribute-field-modifier
          result-field
          make-result-field
          result-field?
          result-field-name
          result-field-type
          interface-entry
          make-interface-entry
          interface-entry?
          interface-entry-name
          interface-entry-methods
          interface-method
          make-interface-method
          interface-method?
          interface-method-name
          interface-method-formals
          interface-method-body)
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
    (fields (immutable name          dialect-parse-name)
            (immutable ops           dialect-parse-ops)
            (immutable cbs           dialect-parse-cbs)
            (immutable dialect-ifaces dialect-parse-dialect-ifaces)))

  ;; A single attribute field declaration inside (define-op ... :attributes (...)).
  ;;   name     — symbol e.g. 'value
  ;;   type     — syntax: predicate (attr) → bool
  ;;   modifier — :required (default) or :optional
  (define-record-type attribute-field
    (fields (immutable name     attribute-field-name)
            (immutable type     attribute-field-type)
            (immutable modifier attribute-field-modifier)))

  ;; A single result field declaration inside (define-op ... :results (...)).
  ;;   name — syntax: identifier (used for accessor name generation)
  ;;   type — syntax: predicate (value) → bool
  (define-record-type result-field
    (fields (immutable name result-field-name)
            (immutable type result-field-type)))

  ;; Result of parse-define-op.
  ;;   name       — op name syntax e.g. #'constant (prefix added by caller)
  ;;   operands   — list of operand-field records
  ;;   attributes — list of attribute-field records
  ;;   results    — list of result-field records
  ;;   op-cbs     — 7-slot vector of Scheme callback syntax or #f (CrestOp slots):
  ;;                  0  :verify                        (op) → bool
  ;;                  1  :verify-regions                (op) → bool
  ;;                  2  :parse                         (parser state) → bool
  ;;                  3  :print                         (op printer name) → void
  ;;                  4  :fold                          (op) → bool
  ;;                  5  :get-canonicalization-patterns (pattern-set) → void
  ;;                  6  :populate-default-attrs        (op-name attrs) → void
  ;; interfaces — list of interface-entry records (one per :interfaces entry).
  ;; Each interface-entry carries the interface name syntax and a list of
  ;; interface-method records for any overridden methods.  An empty methods list
  ;; means "use the default C++ concept."
  (define-record-type op-parse
    (fields (immutable name       op-parse-name)
            (immutable operands   op-parse-operands)
            (immutable attributes op-parse-attributes)
            (immutable results    op-parse-results)
            (immutable op-cbs     op-parse-op-cbs)
            (immutable interfaces op-parse-interfaces)))

  ;; One entry in an op's :interfaces list.
  ;;   name    — identifier syntax for the interface, e.g. #'mlir::FunctionOpInterface
  ;;   methods — list of interface-method records; empty = use default C++ concept
  (define-record-type interface-entry
    (fields (immutable name    interface-entry-name)
            (immutable methods interface-entry-methods)))

  ;; One method override inside an interface-entry.
  ;;   name    — symbol, e.g. 'getFunctionType
  ;;   formals — syntax for the formal parameter list, e.g. #'(self)
  ;;   body    — syntax for the method body, e.g. #'(begin ...)
  (define-record-type interface-method
    (fields (immutable name    interface-method-name)
            (immutable formals interface-method-formals)
            (immutable body    interface-method-body))))
