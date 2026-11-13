#!r6rs
(library (crest pattern-dsl validate)
  (export validate-ast)
  (import (rnrs)
          (for (only (chezscheme) syntax->list) expand)
          (for (rename (rime loop) (:with :rime-with)) expand)
          (for (crest pattern-dsl ast) expand))

  ;;=======================================================================
  ;; Phase 2: Validation - validate syntax and semantics, normalize fields
  ;;=======================================================================

  ;;-----------------------------------------------------------------------
  ;; Main entry point
  ;;-----------------------------------------------------------------------

  (define (validate-ast ast-rec)
    ;; Phase 2 validates and normalizes the AST from Phase 1 (parse).
    ;; Order matters: normalization must happen before validation that depends on it.

    ;; Rule: Parameters (op operands-ref rewriter type-converter) must be present and valid
    (%%validate-parameters ast-rec)

    ;; Normalization: match field from list to vector (enables indexed access in Phase 3)
    (%%normalize-ast-match-to-vector ast-rec)

    ;; Rule: All identifiers in match operations must start with %
    ;; Rule: Result variables must be unique across all operations (FATAL if violated)
    ;; Rule: :where guards must be valid syntax objects (not validated for correctness)
    (%%validate-match-operations ast-rec)

    ;; Rule: Root variable must appear in results (after normalization)
    (%%validate-root-var ast-rec)

    ;; :rewrite :with and :then-let bodies are kept as raw syntax;
    ;; structural validation happens at macro-expansion time in begin-mlir-code.

    ast-rec)

  ;;-----------------------------------------------------------------------
  ;; Top-level AST field validation
  ;;-----------------------------------------------------------------------

  (define (%%validate-parameters ast-rec)
    (define (check-param field-val name)
      (unless (identifier? field-val)
        (syntax-violation 'validate-ast
                          (string-append "Pattern parameter '" name
                                         "' must be an identifier — write (fname op operands-ref rewriter type-converter)")
                          (ast-pattern-expand-function-name ast-rec))))
    ;; operands-ref and type-converter are #f for rewrite patterns (3-param form).
    (let ([is-rewrite? (eq? (ast-pattern-expand-pattern-type ast-rec) 'rewrite)])
      (check-param (ast-pattern-expand-param-op      ast-rec) "op")
      (unless is-rewrite?
        (check-param (ast-pattern-expand-param-operands-ref   ast-rec) "operands-ref"))
      (check-param (ast-pattern-expand-param-rewriter ast-rec) "rewriter")
      (unless is-rewrite?
        (check-param (ast-pattern-expand-param-type-converter ast-rec) "type-converter"))))


  ;;-----------------------------------------------------------------------
  ;; Normalization
  ;;-----------------------------------------------------------------------

  (define (%%normalize-ast-match-to-vector ast-rec)
    (ast-pattern-expand-match-set! ast-rec
                                   (list->vector (ast-pattern-expand-match ast-rec))))

  ;;-----------------------------------------------------------------------
  ;; Match operations validation
  ;;-----------------------------------------------------------------------

  (define (%%validate-match-operations ast-rec)
    (%%validate-match-identifiers-start-with-% ast-rec)
    (%%validate-no-duplicate-result-variables ast-rec))

  (define (%%validate-match-identifiers-start-with-% ast-rec)
    (let ([match-vec (ast-pattern-expand-match ast-rec)])
      (loop :for op-idx :from 0 :below (vector-length match-vec)
            :rime-with match-op := (vector-ref match-vec op-idx)
            :do (begin
                  ;; Validate result variables start with %
                  (loop :for var :in (ast-match-expand-result-var match-op)
                        :do (%%validate-%-identifier var "Result"))
                  ;; Validate operand variables start with %
                  ;; Operands are ast-operand records (parsed and flattened in phase 1)
                  (loop :for operand :in (ast-match-expand-operands match-op)
                        :do (%%validate-%-identifier (ast-operand-var operand) "Operand"))))))

  (define (%%validate-no-duplicate-result-variables ast-rec)
    (let ([match-vec (ast-pattern-expand-match ast-rec)]
          [seen-results (make-hashtable %%identifier-hash bound-identifier=?)])
      (loop :for op-idx :from 0 :below (vector-length match-vec)
            :rime-with match-op := (vector-ref match-vec op-idx)
            :do (loop :for var :in (ast-match-expand-result-var match-op)
                      :do (begin
                            (when (hashtable-contains? seen-results var)
                              (syntax-violation '%%validate-no-duplicate-result-variables
                                                "Duplicate result variable" var))
                            (hashtable-set! seen-results var #t))))))

  (define (%%validate-root-var ast-rec)
    ;; Rule: Root variable must appear as a result in at least one match operation
    ;; Must be called AFTER normalization (needs match vector and normalized result-vars)
    ;; Only checks: codegen finds the root op again (%%find-root-op in codegen.sls).
    (let ([match-vec (ast-pattern-expand-match ast-rec)]
          [root-var (ast-pattern-expand-root-var ast-rec)])
      (let ([found (loop :initially := #f
                         :for op-idx :from 0 :below (vector-length match-vec)
                         :rime-with match-op := (vector-ref match-vec op-idx)
                         :rime-with result-vars := (ast-match-expand-result-var match-op)
                         :rime-with result-idx := (loop :initially := #f
                                                        :for var :in result-vars
                                                        :for idx :from 0
                                                        :when (bound-identifier=? var root-var)
                                                        :break idx)
                         :when result-idx
                         :break (cons op-idx result-idx))])
        (unless (or found
                    ;; Zero-result root op: root-var is the raw op parameter
                    ;; (not a result variable of any match-op).  This is valid
                    ;; when all matched ops have 0 results.
                    (bound-identifier=? root-var (ast-pattern-expand-param-op ast-rec)))
          (syntax-violation '%%validate-root-var
                            "Root variable not found in any match operation result" root-var)))))

  ;;-----------------------------------------------------------------------
  ;; Utilities
  ;;-----------------------------------------------------------------------

  (define (%%identifier-hash id)
    (symbol-hash (syntax->datum id)))

  (define (%%validate-%-identifier var context-msg)
    (unless (identifier? var)
      (syntax-violation '%%validate-match-operations
                        (string-append context-msg " must be identifier") var))
    (let ([var-name (symbol->string (syntax->datum var))])
      (unless (char=? (string-ref var-name 0) #\%)
        (syntax-violation '%%validate-match-operations
                          (string-append context-msg " must start with %") var))))

  )
