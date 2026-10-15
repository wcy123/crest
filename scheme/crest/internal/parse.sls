#!r6rs
;;=======================================================================
;; Pattern Parser - Phase 1
;;=======================================================================
;;
;; Parses pattern DSL syntax into ast-pattern-expand records (defined in pattern-ast.sls).
;; This is phase 1 of the 4-phase macro expansion pipeline.
;;
;; INPUT:  Raw syntax from define-rewrite-pattern or define-conversion-pattern
;; OUTPUT: ast-pattern-expand record with parsed structure
;;
;; Key responsibilities:
;; - Pattern match syntax structure and extract components
;; - Create ast-pattern-expand, ast-match-expand, ast-operation-expand records (NOT datums)
;; - Handle optional clauses (attributes, types, regions, where)
;; - Parse debug flags (:debug-parse, :debug-analyze, etc.)
;; - Validate basic syntax structure (guards in syntax-case)
;;
;;=======================================================================

;;=======================================================================
;; Syntax Reference: Match Operations
;;=======================================================================
;;
;; Variables: All identifiers must start with %
;;   - Results: %a, %out, %result
;;   - Operands: %x, %input
;;
;; Operation name: string or symbol
;;   - "onnx.Add" or onnx.Add
;;
;; Operand groups:
;;   (%x %y)                           - all required
;;   (%x (:optional %y %z))            - x required, y,z optional
;;   (%x (:optional %y) %z)            - x required, y optional, z required
;;   (%x (:variadic %rest))            - x required, rest variadic
;;   (%x (:optional %y) (:variadic %w)) - combined
;;
;; Note: when the spec contains :optional or :variadic, the matched op MUST
;; carry an operandSegmentSizes DenseI32ArrayAttr — without it CREST cannot
;; determine group boundaries and the match returns #f.
;;
;; Guards (:where clause):
;;   :where <scheme-expr>
;;   - Returns truthy to match, falsy to fail
;;   - Early return (executes immediately after matching operation)
;;   - Can access result variables, call FFI functions
;;
;; Complete match operation examples:
;;   %a = "onnx.Conv" (%x %w)
;;
;;   %a = "onnx.Conv" (%x %w)
;;      :where (let ([$ks (mlir-operation-get-attr %a "kernel_shape")])
;;               (and $ks (is-1x1-kernel? $ks)))
;;
;;   %b = "test.op" (%x (:optional %y %z))
;;      :where (mlir-operation-has-one-use %b)
;;
;; Type matching: NOT SUPPORTED
;;   - MLIR's DRR/PDLL also make types optional
;;   - Type verification happens in operation verifiers
;;
;;=======================================================================

(library (crest internal parse)
  (export parse-to-ast)
  (import (except (rnrs) =)
          (for (only (chezscheme) syntax->list generate-temporaries) expand)
          (for (crest internal keywords) expand)
          (for (crest internal ast) expand))

  ;; %%wildcard? — #t when identifier datum is exactly %_
  (define-syntax %%wildcard?
    (lambda (stx)
      (syntax-case stx ()
        [(_ id) #'(eq? (syntax->datum id) '%_)])))

  ;; %%fresh-wildcard — replace a %_ syntax identifier with a fresh unique
  ;; identifier that still starts with % (so validation passes) but is
  ;; never equal to any other wildcard or user-written variable.
  (define (%%fresh-wildcard ctx)
    (let* ([tmp   (car (generate-temporaries (list ctx)))]
           [name  (string->symbol
                   (string-append "%" (symbol->string (syntax->datum tmp))))])
      (datum->syntax tmp name)))

  ;; %%freshen-wildcards — replace every %_ in a list of result identifiers
  ;; with a fresh unique identifier.  Non-wildcard identifiers are unchanged.
  (define (%%freshen-wildcards vars)
    (map (lambda (var)
           (if (%%wildcard? var) (%%fresh-wildcard var) var))
         vars))

  ;;=======================================================================
  ;; SECTION 1: Entry Points
  ;;=======================================================================

  (define (parse-to-ast whole-stx type)
    (syntax-case whole-stx ()
      [(_ . rest)
       (%%parse-rest #'rest (make-ast-pattern-expand type))]))

  ;;-----------------------------------------------------------------------
  ;; %%parse-rest - Parse function name, debug flags, then dispatch to :if-match
  ;;-----------------------------------------------------------------------
  (define (%%parse-rest rest ast)
    (syntax-case rest (:debug-parse :debug-validate :debug-analyze :debug-codegen :if-match :then-let :rewrite :with)
      ;; Debug flags
      [(:debug-parse . more)
       (begin
         (ast-pattern-expand-debug-parse?-set! ast #t)
         (%%parse-rest #'more ast))]

      [(:debug-validate . more)
       (begin
         (ast-pattern-expand-debug-validate?-set! ast #t)
         (%%parse-rest #'more ast))]

      [(:debug-analyze . more)
       (begin
         (ast-pattern-expand-debug-analyze?-set! ast #t)
         (%%parse-rest #'more ast))]

      [(:debug-codegen . more)
       (begin
         (ast-pattern-expand-debug-codegen?-set! ast #t)
         (%%parse-rest #'more ast))]

      ;; 3-param form for rewrite patterns: (fname op rewriter)
      [((fname p-op p-rewriter) . more)
       (and (identifier? #'fname)
            (not (ast-pattern-expand-function-name ast))
            (eq? (ast-pattern-expand-pattern-type ast) 'rewrite))
       (begin
         (ast-pattern-expand-function-name-set!         ast #'fname)
         (ast-pattern-expand-param-op-set!              ast #'p-op)
         (ast-pattern-expand-param-operands-ref-set!    ast #f)
         (ast-pattern-expand-param-rewriter-set!        ast #'p-rewriter)
         (ast-pattern-expand-param-type-converter-set!  ast #f)
         (%%parse-rest #'more ast))]

      ;; 5-param form for conversion patterns: (fname op operands-ref rewriter type-converter)
      [((fname p-op p-operands-ref p-rewriter p-type-converter) . more)
       (and (identifier? #'fname)
            (not (ast-pattern-expand-function-name ast))
            (eq? (ast-pattern-expand-pattern-type ast) 'conversion))
       (begin
         (ast-pattern-expand-function-name-set!         ast #'fname)
         (ast-pattern-expand-param-op-set!              ast #'p-op)
         (ast-pattern-expand-param-operands-ref-set!    ast #'p-operands-ref)
         ;; p-rewriter is the user-chosen identifier for the rewriter parameter.
         ;; The codegen uses it as the lambda parameter name AND as the target of
         ;; mlir::RewriterBase::setInsertionPoint and begin-mlir-code in the
         ;; generated rewrite body — so it must match the user's function signature.
         (ast-pattern-expand-param-rewriter-set!        ast #'p-rewriter)
         (ast-pattern-expand-param-type-converter-set!  ast #'p-type-converter)
         (%%parse-rest #'more ast))]

      ;; This clause is NOT dead code — it is reached on the SECOND recursive
      ;; call to %%parse-rest.  The 3-param/5-param clauses above consume the
      ;; function signature and call (%%parse-rest #'more ast) where #'more
      ;; begins with :if-match.  The fender (ast-pattern-expand-function-name ast)
      ;; confirms the function name was already set, ensuring we never process
      ;; :if-match before a valid signature clause has run.
      [(:if-match . match-rest)
       (ast-pattern-expand-function-name ast)
       (%%parse-match-ops-recursive #'match-rest '() ast)]

      [_ (syntax-violation '%%parse-rest
                           "Expected function name and :if-match clause"
                           rest)]))

  ;;=======================================================================
  ;; SECTION 2: Recursive Collectors (High-Level Parsing)
  ;;=======================================================================
  ;;
  ;; These functions orchestrate the parsing by recursively collecting
  ;; operations and dispatching to detail parsers.
  ;;
  ;; Call graph:
  ;;   %%parse-match-ops-recursive  → %%parse-after-match
  ;;        ↓ creates ast-match-expand    ↓ parses :then-let         ↓ collects raw syntax
  ;;
  ;;=======================================================================

  ;;-----------------------------------------------------------------------
  ;; %%parse-match-ops-recursive - Collect match operations
  ;;-----------------------------------------------------------------------
  ;; Stops at :then-let or :rewrite. Creates ast-match-expand records directly.
  ;; Note: Operands are parsed and flattened to ast-operand records in phase 1.
  ;; Validation (% prefix check) happens in phase 2 (pattern-validate.sls).
  ;;
  (define (%%parse-match-ops-recursive rest-stx acc-ops ast)
    (syntax-case rest-stx (:then-let :rewrite :where =)
      ;; Stop: :then-let or :rewrite
      [(:then-let . _)
       (begin
         (ast-pattern-expand-match-set! ast (reverse acc-ops))
         (%%parse-after-match rest-stx ast))]

      [(:rewrite . _)
       (begin
         (ast-pattern-expand-match-set! ast (reverse acc-ops))
         (%%parse-after-match rest-stx ast))]

      ;; Single-result shorthand: %out = op (...)  →  normalise to (list #'%out)
      [(result = op-name (operand ...) :where guard-expr . rest)
       (identifier? #'result)
       (%%parse-match-ops-recursive #'((result) = op-name (operand ...) :where guard-expr . rest) acc-ops ast)]
      ;; Multi-result terminal: (%a %b ...) = op (...)
      ;; result-var stored as a list of identifiers; single-result shorthand above
      ;; also normalises to a list so all downstream phases see a uniform representation.
      ;; terminal branch 1
      [((result ...) = op-name (operand ...) :where guard-expr . rest)
       (and (for-all identifier? (syntax->list #'(result ...)))
            (let ([d (syntax->datum #'op-name)])
              (or (string? d) (symbol? d))))
       (let* ([d        (syntax->datum #'op-name)]
              [op-norm  (if (string? d) d (symbol->string d))]
              [operands (%%parse-operands #'(operand ...))]
              [results  (%%freshen-wildcards (syntax->list #'(result ...)))]
              [match-op (make-ast-match-expand results op-norm operands #'guard-expr)])
         (%%parse-match-ops-recursive #'rest (cons match-op acc-ops) ast))]

      [(result = op-name (operand ...) . rest)
       (identifier? #'result)
       (%%parse-match-ops-recursive #'((result) = op-name (operand ...) . rest) acc-ops ast)]
      ;; terminal branch 2
      [((result ...) = op-name (operand ...) . rest)
       (and (for-all identifier? (syntax->list #'(result ...)))
            (let ([d (syntax->datum #'op-name)])
              (or (string? d) (symbol? d))))
       (let* ([d        (syntax->datum #'op-name)]
              [op-norm  (if (string? d) d (symbol->string d))]
              [operands (%%parse-operands #'(operand ...))]
              [results  (%%freshen-wildcards (syntax->list #'(result ...)))]
              [match-op (make-ast-match-expand results op-norm operands #f)])
         (%%parse-match-ops-recursive #'rest (cons match-op acc-ops) ast))]

      [_ (syntax-violation '%%parse-match-ops-recursive
                           "Invalid3 match operation (expected: result = \"op\" (...) [:where expr])" rest-stx)]))


  ;;-----------------------------------------------------------------------
  ;; %%parse-operands - Parse operand list, flattening groups
  ;;-----------------------------------------------------------------------
  ;;
  ;; Parses operand syntax and flattens (:optional ...) and (:variadic ...)
  ;; groups into individual ast-operand records tagged with their kind.
  ;;
  ;; Input syntax: (%x (:optional %y %z) %w (:variadic %rest))
  ;; Output: list of ast-operand records:
  ;;   [ast-operand('required, #'%x),
  ;;    ast-operand('optional, #'%y),
  ;;    ast-operand('optional, #'%z),
  ;;    ast-operand('required, #'%w),
  ;;    ast-operand('variadic, #'%rest)]
  ;;
  ;; Phase 1 (parse) checks:
  ;; - All operands are identifiers (syntax structure)
  ;; - (:variadic ...) has exactly one variable
  ;;
  ;; Phase 2 (validate) checks:
  ;; - All identifiers start with % (semantic rule)
  ;;
  (define (%%parse-operands operands-stx)
    ;; Freshen a single identifier: replace %_ with a fresh unique name, pass others through.
    (define (freshen v) (if (%%wildcard? v) (%%fresh-wildcard v) v))
    (define (parse-one operand-stx)
      (syntax-case operand-stx (:optional :variadic)
        ;; Optional group: (:optional %y %z) → flatten to multiple optional operands
        ;; %_ is allowed and freshened so multiple (:optional %_) never collide.
        [(:optional var ...)
         (let ([vars (syntax->list #'(var ...))])
           (for-each check-identifier vars)
           (map (lambda (v) (make-ast-operand ':optional (freshen v))) vars))]

        ;; Variadic group: (:variadic %a %b ...) → one variadic operand per variable.
        ;; Each variable corresponds to one variadic group in operandSegmentSizes
        ;; and is bound to a list of that group's values.
        ;; (:variadic %_) is allowed: match any number of values, bind none.
        [(:variadic var ...)
         (let ([vars (syntax->list #'(var ...))])
           (when (null? vars)
             (syntax-violation '%%parse-operands "(:variadic) requires at least one variable" operand-stx))
           (for-each check-identifier vars)
           (map (lambda (v) (make-ast-operand ':variadic (freshen v))) vars))]

        ;; Wildcard operand: %_ → fresh unique identifier, never shared
        [var
         (and (identifier? #'var) (%%wildcard? #'var))
         (list (make-ast-operand ':required (%%fresh-wildcard #'var)))]

        ;; Required operand: %x → single required operand
        [var
         (identifier? #'var)
         (list (make-ast-operand ':required #'var))]

        [_
         (syntax-violation '%%parse-operands
                           "Invalid operand syntax (expected: identifier, (:optional ...), or (:variadic var))"
                           operand-stx)]))

    ;; Helper: check syntax structure (identifier check only, no % validation)
    (define (check-identifier var)
      (unless (identifier? var)
        (syntax-violation '%%parse-operands "Operand must be identifier" var)))

    (apply append (map parse-one (syntax->list operands-stx))))


  ;;-----------------------------------------------------------------------
  ;; %%parse-after-match - Parse optional :then-let, then :rewrite
  ;;-----------------------------------------------------------------------
  (define (%%parse-after-match rest-stx ast)
    (syntax-case rest-stx (:then-let :rewrite :with)
      ;; Empty :then-let — delegate to the :rewrite-only path.
      ;; :rewrite without :then-let.
      [(:rewrite root :with . rewrite-rest)
       (%%parse-after-match #'(:then-let () :rewrite root :with . rewrite-rest) ast)]

      ;; :then-let with bindings — all vars must be identifiers.
      [(:then-let ((var expr) ...) :rewrite root :with . rewrite-rest)
       (and (identifier? #'root)
            (for-all identifier? (syntax->list #'(var ...))))
       (begin
         (ast-pattern-expand-root-var-set! ast #'root)
         (ast-pattern-expand-then-let-set! ast
                                           (map make-ast-then-let-binding-expand
                                                (syntax->list #'(var ...))
                                                (syntax->list #'(expr ...))))
         (ast-pattern-expand-rewrite-set! ast (syntax->list #'rewrite-rest))
         ast)]

      [_ (syntax-violation 'define-conversion-pattern
                           "Expected [:then-let (...)] :rewrite root :with rewrite-ops..." rest-stx)]))

  )
