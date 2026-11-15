#!r6rs
(library (crest pattern-dsl analyze)
  (export analyze-ast
          binding-manager-bindings)
  (import (rnrs)
          (only (chezscheme) syntax->list format printf)
          (for (rename (rime loop) (:with :rime-with)) expand)
          (crest pattern-dsl ast)
          (crest pattern-dsl actions))

  ;;=======================================================================
  ;; Phase 3: Analysis - build bindings and actions for pattern matching
  ;;=======================================================================

  ;;-----------------------------------------------------------------------
  ;; Main entry point
  ;;-----------------------------------------------------------------------

  (define (analyze-ast ast-rec)
    (%%analyze-match-operations ast-rec)
    ast-rec)

  ;;-----------------------------------------------------------------------
  ;; Match operations analysis
  ;;-----------------------------------------------------------------------

  (define (%%analyze-match-operations ast-rec)
    ;; Phase 2 validation guarantees: root variable exists as a result in some match operation
    (let* ([match-vec   (ast-pattern-expand-match ast-rec)]
           [root-var    (ast-pattern-expand-root-var ast-rec)]
           ;; For zero-result root ops, root-var is the raw op parameter (not a
           ;; result variable), so %%find-root-op-idx returns #f.  Fall back to
           ;; index 0 — valid for single-op patterns like toy.return/toy.print.
           [root-op-idx (or (%%find-root-op-idx match-vec root-var) 0)])

      ;; Build match actions starting from root operation
      (let* ([bindings-and-actions (%%build-bindings-and-actions ast-rec match-vec root-op-idx root-var)]
             [binding-mgr (car bindings-and-actions)]
             [actions (cdr bindings-and-actions)])

        (ast-pattern-expand-match-analysis-set! ast-rec
                                                (make-ast-match-analysis binding-mgr actions)))))

  ;;-----------------------------------------------------------------------
  ;; DAG traversal and action generation
  ;;-----------------------------------------------------------------------

  (define (%%build-bindings-and-actions ast-rec match-vec root-op-idx root-var)
    ;; Create binding manager and visited vector locally
    (let* ([binding-mgr (%%collect-all-identifiers match-vec)]
           [visited (make-vector (vector-length match-vec) #f)]
           [acc '()]
           [pattern-type (ast-pattern-expand-pattern-type ast-rec)]
           [is-conversion? (eq? pattern-type 'conversion)])

      ;; Named let for DAG traversal
      ;; Precondition: result-var must be bound (used to navigate to operation)
      (let traverse ([op-idx root-op-idx]
                     [result-var root-var])
        (unless (vector-ref visited op-idx)
          ;; Mark as visited
          (vector-set! visited op-idx #t)

          (let* ([match-op (vector-ref match-vec op-idx)]
                 [operands (ast-match-expand-operands match-op)]  ; list of ast-operand records
                 ;; Cache binding entries - avoid repeated hashtable lookups
                 ;; Extract var field from ast-operand for lookup
                 [entries (map (lambda (op) (%%find-binding-entry binding-mgr (ast-operand-var op))) operands)])

            ;; Emit header actions (building backwards, will reverse at end).
            ;; For zero-result root ops, result-var is the raw op parameter
            ;; (not a Value) — use action:set-root-op to avoid calling
            ;; getDefiningOp on a non-Value.
            (set! acc (cons (if (and (= op-idx root-op-idx)
                                     (null? (ast-match-expand-result-var (vector-ref match-vec op-idx))))
                                (action:set-root-op op-idx)
                                (action:set-current-op op-idx result-var))
                            acc))
            ;; Skip :check-op for :any ops — they match any op name at runtime.
            ;; Use :where to filter which ops are acceptable.
            ;; validate.sls normalizes symbol op-names to strings, so :any
            ;; op-name is a normalized string; ":any" means match any op name.
            (unless (string=? (ast-match-expand-op-name match-op) ":any")
              (set! acc (cons (action:check-op op-idx) acc)))

            ;; Bind ALL result variables of this operation.
            ;; For non-root ops emit action:bind-result so the Scheme variable
            ;; is set to the actual mlir::Value at match time (needed for :where
            ;; guards and :then-let that reference non-root result variables).
            ;; The root op's results are set by root-result-setters before checks.
            (loop :for res-var :in (ast-match-expand-result-var match-op)
                  :for result-idx :from 0
                  :rime-with result-entry := (%%find-binding-entry binding-mgr res-var)
                  :do (begin
                        (binding-entry-bound?-set! result-entry #t)
                        (when (not (= op-idx root-op-idx))
                          (set! acc (cons (action:bind-result op-idx result-idx res-var) acc)))))


            ;; Process operands.
            ;; If any operand is optional/variadic, delegate the entire op's operand
            ;; binding to operation-get-operands (reads operandSegmentSizes internally).
            ;; For all-required ops, bind each operand individually.
            (let ([has-flex? (loop :initially := #f
                                   :for op :in operands
                                   :break #t :if (memq (ast-operand-kind op) '(:optional :variadic)))])
              (if has-flex?
                  ;; Flex path: one action binds all operands via operation-get-operands.
                  (begin
                    (set! acc (cons (action:bind-operands
                                     op-idx
                                     (map (lambda (operand)
                                            (datum->syntax (ast-operand-var operand)
                                                           (ast-operand-kind operand)))
                                          operands)
                                     (map ast-operand-var operands))
                                    acc))
                    (for-each (lambda (operand entry)
                                (binding-entry-bound?-set! entry #t)
                                (when (binding-entry-is-result? entry)
                                  (let ([producer-op-idx (%%find-operation-by-result
                                                          match-vec (ast-operand-var operand))])
                                    (traverse producer-op-idx (ast-operand-var operand)))))
                              operands entries))
                  ;; All-required path.
                  ;; Conversion root: one :bind-argument-operand per operand (from operands-ref).
                  ;; All other ops: one :bind-operands for all operands; codegen distinguishes
                  ;;   fresh (set!) from already-bound (eqv?) via unbound-value?.
                  (if (and is-conversion? (= op-idx root-op-idx))
                      (loop :for operand :in operands
                            :for entry :in entries
                            :for operand-idx :from 0
                            :rime-with operand-var := (ast-operand-var operand)
                            :rime-with is-result := (binding-entry-is-result? entry)
                            :do (begin
                                  (set! acc (cons (action:bind-argument-operand operand-idx operand-var) acc))
                                  (binding-entry-bound?-set! entry #t)
                                  (when is-result
                                    (let ([producer-op-idx (%%find-operation-by-result match-vec operand-var)])
                                      (traverse producer-op-idx operand-var)))))
                      (begin
                        (set! acc (cons (action:bind-operands
                                         op-idx
                                         (map (lambda (operand)
                                                (datum->syntax (ast-operand-var operand) ':required))
                                              operands)
                                         (map ast-operand-var operands))
                                        acc))
                        (for-each (lambda (operand entry)
                                    (binding-entry-bound?-set! entry #t)
                                    (when (binding-entry-is-result? entry)
                                      (let ([producer-op-idx (%%find-operation-by-result
                                                              match-vec (ast-operand-var operand))])
                                        (traverse producer-op-idx (ast-operand-var operand)))))
                                  operands entries)))))

            ;; Emit :where guard AFTER this op's own operands are bound.
            ;;
            ;; Binding scope at :where time (what the guard CAN reference):
            ;;   - This op's own operands (all bound before check-where)
            ;;   - Operands of ops traversed as THIS op's operands (deeper in the DAG)
            ;;   - `op` parameter (always available — the matched root op)
            ;;
            ;; NOT yet bound at :where time:
            ;;   - Operands of PARENT ops that come AFTER this op's traversal
            ;;   (e.g. in Q→add→dq chain, dq's :where cannot see Q's remaining operands)
            ;;
            ;; To use a parent op's operand in a guard, attach the :where to the parent
            ;; op. The root op's :where fires last (after all sub-traversals) and can
            ;; reference all variables.
            (let ([where-expr (ast-match-expand-where-expr match-op)])
              (when where-expr
                (set! acc (cons (action:check-where where-expr op-idx) acc)))))))

      ;; Warn about unvisited operations
      (%%error-unvisited-operations match-vec visited)

      ;; Return (binding-mgr . reversed-actions)
      (cons binding-mgr (reverse acc))))

  ;;-----------------------------------------------------------------------
  ;; Identifier collection and binding manager construction
  ;;-----------------------------------------------------------------------

  (define (%%collect-all-identifiers match-vec)
    ;; Two-pass collection:
    ;; Pass 1: collect operand occurrences (last write wins)
    ;; Pass 2: results overwrite everything
    ;; Note: duplicate result variables are validated earlier, guaranteed not to happen here
    (let ([ht (make-hashtable %%identifier-hash bound-identifier=?)])

      ;; Pass 1: Collect operand occurrences (last write wins)
      ;; operands is a list of ast-operand records after validation phase
      (loop :for op-idx :from 0 :below (vector-length match-vec)
            :rime-with match-op := (vector-ref match-vec op-idx)
            :do (loop :for operand :in (ast-match-expand-operands match-op)
                      :for operand-idx :from 0
                      :rime-with operand-var := (ast-operand-var operand)
                      :do (hashtable-set! ht operand-var
                                          (make-binding-entry operand-var #f #f #f op-idx operand-idx #f))))

      ;; Pass 2: Results overwrite (duplicate results validated earlier)
      (loop :for op-idx :from 0 :below (vector-length match-vec)
            :rime-with match-op := (vector-ref match-vec op-idx)
            :do (loop :for result-var :in (ast-match-expand-result-var match-op)
                      :for result-idx :from 0
                      :do (hashtable-set! ht result-var
                                          (make-binding-entry result-var #t op-idx result-idx #f #f #f))))

      ;; Return binding manager
      (make-binding-manager ht)))

  ;;-----------------------------------------------------------------------
  ;; Binding records and manager
  ;;-----------------------------------------------------------------------

  ;; Record: binding-entry
  ;; Represents a single identifier binding (result or operand)
  (define-record-type binding-entry
    (fields id                    ; identifier (syntax object)
            is-result?            ; #t if result variable, #f if only operand
            result-op-idx         ; if is-result?, the operation index (else #f)
            result-idx            ; if is-result?, the result index (else #f)
            operand-op-idx        ; if operand, one operand occurrence op-idx (else #f)
            operand-idx           ; if operand, one operand occurrence index (else #f)
            (mutable bound?)))    ; #t when bound, initially #f

  ;; Record: binding-manager
  ;; Manages all identifier bindings for pattern matching
  (define-record-type binding-manager
    (fields bindings-table))      ; hashtable: identifier → binding-entry

  (define (binding-manager-bindings mgr)
    (binding-manager-bindings-table mgr))

  (define (%%find-binding-entry mgr id)
    (hashtable-ref (binding-manager-bindings mgr) id #f))

  ;;-----------------------------------------------------------------------
  ;; Helper functions
  ;;-----------------------------------------------------------------------

  (define (%%find-root-op-idx match-vec root-var)
    ;; Find the index of the match-op whose result list contains root-var.
    (loop :initially := #f
          :for op-idx :from 0 :below (vector-length match-vec)
          :rime-with match-op := (vector-ref match-vec op-idx)
          :break op-idx :if (loop :initially := #f
                                  :for var :in (ast-match-expand-result-var match-op)
                                  :when (bound-identifier=? var root-var)
                                  :break #t)))

  (define (%%identifier-hash id)
    (symbol-hash (syntax->datum id)))

  ;; An op of the match that no value joins to the root is never reached when the pattern matches (the match walks from
  ;; the root through the operands and the results), so it is a mistake in the pattern.
  (define (%%error-unvisited-operations match-vec visited)
    (loop :for op-idx :from 0 :below (vector-length match-vec)
          :rime-with match-op := (vector-ref match-vec op-idx)
          :when (not (vector-ref visited op-idx))
          :do (let* ([results (ast-match-expand-result-var match-op)]
                     [operands (ast-match-expand-operands match-op)]
                     ;; The syntax of one of its variables, for the position.
                     [where (cond [(pair? results) (car results)]
                                  [(pair? operands) (ast-operand-var (car operands))]
                                  [else #f])])
                (syntax-violation 'pattern
                                  (string-append "the match operation " (ast-match-expand-op-name match-op)
                                                 " is not connected to the root: no value of it is used by an operation"
                                                 " that leads to the root, so it is never reached")
                                  where))))

  (define (%%find-operation-by-result match-vec result-var)
    (loop :initially := #f
          :for op-idx :from 0 :below (vector-length match-vec)
          :rime-with match-op := (vector-ref match-vec op-idx)
          :rime-with result-vars := (ast-match-expand-result-var match-op)
          :break op-idx :if (loop :initially := #f
                                  :for var :in result-vars
                                  :when (bound-identifier=? var result-var)
                                  :break #t))))
