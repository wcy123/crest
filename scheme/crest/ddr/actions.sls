#!r6rs
(library (crest ddr actions)
  (export action:set-current-op
          action:check-op
          action:bind-operand
          action:bind-optional-operand
          action:bind-operand-with-offset
          action:bind-argument-operand
          action:check-eq
          action:check-where
          action:bind-result)
  (import (rnrs))

  ;; Action constructors with labeled fields using pairs
  ;; Output format: (:tag (field-name . value) ...)
  ;;
  ;; Actions represent runtime pattern matching algorithm:
  ;; - :set-current-op - Navigate to operation in DAG
  ;; - :check-op - Verify operation type matches
  ;; - :bind-operand - Bind free variable to operation's operand (can match any input)
  ;; - :bind-argument-operand - Bind root operand from operands-ref (conversion patterns only)
  ;; - :check-eq - Verify bound variable equals current operand

  (define (action:set-current-op op-idx var)
    (list ':set-current-op
          (cons 'op-idx op-idx)
          (cons 'var var)))

  (define (action:check-op op-idx)
    (list ':check-op
          (cons 'op-idx op-idx)))

  (define (action:bind-operand op-idx operand-idx var)
    (list ':bind-operand
          (cons 'op-idx op-idx)
          (cons 'operand-idx operand-idx)
          (cons 'var var)))

  ;; Bind an optional operand: present when total operands > base-idx + n-required-after.
  ;; offset-var-sym: a Scheme symbol naming the per-op offset accumulator variable
  ;; (initialized to 0 before matching; incremented each time an optional is present).
  ;; base-idx: the static operand index assuming all optional operands before this are present.
  ;; n-required-after: count of required operands following this optional in the same op.
  (define (action:bind-optional-operand op-idx base-idx var offset-var-sym n-required-after)
    (list ':bind-optional-operand
          (cons 'op-idx          op-idx)
          (cons 'base-idx        base-idx)
          (cons 'var             var)
          (cons 'offset-var-sym  offset-var-sym)
          (cons 'n-required-after n-required-after)))

  ;; Bind a required operand that follows one or more optional operands.
  ;; The actual runtime index is: static-idx - n-opt-before + offset-var
  ;; where offset-var is the accumulated count of optional operands actually present.
  (define (action:bind-operand-with-offset op-idx static-idx var offset-var-sym n-opt-before)
    (list ':bind-operand-with-offset
          (cons 'op-idx         op-idx)
          (cons 'static-idx     static-idx)
          (cons 'var            var)
          (cons 'offset-var-sym offset-var-sym)
          (cons 'n-opt-before   n-opt-before)))

  (define (action:bind-argument-operand operand-idx var)
    (list ':bind-argument-operand
          (cons 'operand-idx operand-idx)
          (cons 'var var)))

  (define (action:check-eq op-idx operand-idx var)
    (list ':check-eq
          (cons 'op-idx op-idx)
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
