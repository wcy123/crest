#!r6rs
(library (crest pattern-dsl actions)
  (export action:set-current-op
          action:check-op
          action:bind-operands
          action:bind-argument-operand
          action:check-where
          action:bind-result)
  (import (rnrs))

  ;; Action constructors with labeled fields using pairs
  ;; Output format: (:tag (field-name . value) ...)
  ;;
  ;; Actions represent runtime pattern matching algorithm:
  ;; - :set-current-op          - Navigate to operation in DAG
  ;; - :check-op                - Verify operation type and result count
  ;; - :bind-operands           - Bind all operands; fresh → set!, already-bound → eqv?
  ;; - :bind-argument-operand   - Bind root operand from operands-ref (conversion patterns only)

  (define (action:set-current-op op-idx var)
    (list ':set-current-op
          (cons 'op-idx op-idx)
          (cons 'var var)))

  (define (action:check-op op-idx)
    (list ':check-op
          (cons 'op-idx op-idx)))

  ;; Bind all operands of an op via operation-get-operands.
  ;; spec: list of syntax keyword objects (:required / :optional / :variadic)
  ;; vars: list of syntax identifiers (positionally matched to spec)
  ;; Fresh vars are set!; already-bound vars are checked via eqv? (DAG diamond).
  (define (action:bind-operands op-idx spec vars)
    (list ':bind-operands
          (cons 'op-idx op-idx)
          (cons 'spec   spec)
          (cons 'vars   vars)))

  (define (action:bind-argument-operand operand-idx var)
    (list ':bind-argument-operand
          (cons 'operand-idx operand-idx)
          (cons 'var var)))

  ;; :where guard — a raw Scheme expression evaluated after all operands of
  ;; the enclosing match-op are bound.  Returns truthy to continue, falsy to fail.
  ;; op-idx identifies the currently matched op so the codegen can substitute
  ;; :current-op and (:attr ...) references in the expression.
  (define (action:check-where expr op-idx)
    (list ':check-where
          (cons 'op-idx op-idx)
          (cons 'expr expr)))

  ;; Bind a non-root result variable to the Value produced by a matched op.
  ;; Emitted for each result var of every non-root match op after :check-op,
  ;; so the variable can be used in :where guards and :then-let.
  (define (action:bind-result op-idx result-idx var)
    (list ':bind-result
          (cons 'op-idx     op-idx)
          (cons 'result-idx result-idx)
          (cons 'var        var))))
