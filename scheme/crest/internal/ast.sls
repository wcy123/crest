#!r6rs
;;=======================================================================
;; Pattern AST Record Definitions
;;=======================================================================
;;
;; This library defines the AST record types used throughout the 4-phase
;; pattern DSL macro expansion pipeline:
;;
;;   Phase 1 (parse)    - Parse syntax to AST records (this file defines structure)
;;   Phase 2 (validate) - Validate AST; ast-pattern-expand fields enriched in-place
;;   Phase 3 (analyze)  - Build bindings and actions, stored in ast-pattern-expand
;;   Phase 4 (codegen)  - Generate final lambda from AST
;;
;; Immutability discipline:
;;   ast-match-expand and ast-operand fields are immutable — parse sets them
;;   once and later phases only read them.
;;   ast-pattern-expand fields are mutable because validate/analyze enrich them
;;   (e.g. root-op-index, match-bindings, match-actions).
;;
;;=======================================================================

(library (crest internal ast)
  (export ast-pattern-expand make-ast-pattern-expand ast-pattern-expand?
          ast-pattern-expand-pattern-type ast-pattern-expand-pattern-type-set!
          ast-pattern-expand-function-name ast-pattern-expand-function-name-set!
          ast-pattern-expand-param-op ast-pattern-expand-param-op-set!
          ast-pattern-expand-param-operands-ref ast-pattern-expand-param-operands-ref-set!
          ast-pattern-expand-param-rewriter ast-pattern-expand-param-rewriter-set!
          ast-pattern-expand-param-type-converter ast-pattern-expand-param-type-converter-set!
          ast-pattern-expand-root-var ast-pattern-expand-root-var-set!
          ast-pattern-expand-match ast-pattern-expand-match-set!
          ast-pattern-expand-match-analysis ast-pattern-expand-match-analysis-set!

          ast-match-analysis make-ast-match-analysis ast-match-analysis?
          ast-match-analysis-bindings
          ast-match-analysis-actions
          ast-pattern-expand-rewrite ast-pattern-expand-rewrite-set!
          ast-pattern-expand-then-let ast-pattern-expand-then-let-set!
          ast-pattern-expand-debug-parse? ast-pattern-expand-debug-parse?-set!
          ast-pattern-expand-debug-validate? ast-pattern-expand-debug-validate?-set!
          ast-pattern-expand-debug-analyze? ast-pattern-expand-debug-analyze?-set!
          ast-pattern-expand-debug-codegen? ast-pattern-expand-debug-codegen?-set!
          ast-pattern-expand-debug-matching? ast-pattern-expand-debug-matching?-set!

          ast-match-expand make-ast-match-expand ast-match-expand?
          ast-match-expand-result-var
          ast-match-expand-op-name
          ast-match-expand-operands
          ast-match-expand-where-expr

          ast-operation-expand make-ast-operation-expand ast-operation-expand?
          ast-operation-expand-result-var ast-operation-expand-result-var-set!
          ast-operation-expand-op-name ast-operation-expand-op-name-set!
          ast-operation-expand-operands ast-operation-expand-operands-set!
          ast-operation-expand-regions ast-operation-expand-regions-set!
          ast-operation-expand-attributes ast-operation-expand-attributes-set!
          ast-operation-expand-result-types ast-operation-expand-result-types-set!

          ast-then-let-binding-expand make-ast-then-let-binding-expand ast-then-let-binding-expand?
          ast-then-let-binding-expand-var ast-then-let-binding-expand-var-set!
          ast-then-let-binding-expand-expr ast-then-let-binding-expand-expr-set!

          ast-region-expand make-ast-region-expand ast-region-expand?
          ast-region-expand-blocks ast-region-expand-blocks-set!

          ast-block-expand make-ast-block-expand ast-block-expand?
          ast-block-expand-label ast-block-expand-label-set!
          ast-block-expand-arguments ast-block-expand-arguments-set!
          ast-block-expand-operations ast-block-expand-operations-set!

          ast-operand make-ast-operand ast-operand?
          ast-operand-kind
          ast-operand-var

          ast-scheme-binding-expand make-ast-scheme-binding-expand ast-scheme-binding-expand?
          ast-scheme-binding-expand-var ast-scheme-binding-expand-var-set!
          ast-scheme-binding-expand-expr ast-scheme-binding-expand-expr-set!)
  (import (rnrs)
          (only (chezscheme) getenv))

  ;;=======================================================================
  ;; AST RECORD HIERARCHY (top-down tree order: root → leaves)
  ;;=======================================================================
  ;;
  ;; Tree structure of pattern AST (top-down presentation):
  ;;
  ;; ast-pattern-expand (ROOT)
  ;; ├── match: list of ast-match-expand
  ;; │   └── operands: list of ast-operand
  ;; ├── then-let: list of ast-then-let-binding-expand
  ;; └── rewrite: list of ast-operation-expand
  ;;     └── regions: list of ast-region-expand
  ;;         └── blocks: list of ast-block-expand
  ;;             └── operations: list of ast-operation-expand (recursive)
  ;;
  ;; Reading flow: Start at root (pattern definition), drill down into
  ;; match operations, operand details, rewrite operations, region/block structure.
  ;;
  ;;=======================================================================

  ;;-----------------------------------------------------------------------
  ;; ROOT RECORD: ast-pattern-expand
  ;;-----------------------------------------------------------------------
  ;;
  ;; Represents a complete pattern definition across all phases.
  ;; Created by parse phase, enriched by validate/analyze phases, consumed by codegen.
  ;;
  ;; Contains:
  ;;   - match: list of ast-match-expand (operations to match)
  ;;   - then-let: list of ast-then-let-binding-expand (computed bindings)
  ;;   - rewrite: list of ast-operation-expand (operations to construct)
  ;;
  ;; ast-match-analysis — set once by analyze; groups bindings + actions.
  (define-record-type (ast-match-analysis make-ast-match-analysis ast-match-analysis?)
    (fields
     (immutable bindings)    ;; binding-manager — maps all %vars to binding-entry records
     (immutable actions)))   ;; list of actions — ordered runtime matching sequence

  (define-record-type (ast-pattern-expand make-ast-pattern-expand ast-pattern-expand?)
    (protocol
     (lambda (new)
       (lambda (pattern-type)
         (new pattern-type  ;; pattern-type: 'conversion or 'rewrite
              #f            ;; function-name: set by parse-rest
              #f            ;; param-op
              #f            ;; param-operands-ref
              #f            ;; param-rewriter
              #f            ;; param-type-converter
              #f            ;; root-var: set by parse-rest
              '()           ;; match: accumulated during parse
              #f            ;; match-analysis: ast-match-analysis, set by analyze
              '()           ;; rewrite: accumulated during parse
              '()           ;; then-let: accumulated during parse
              #f            ;; debug-parse?
              #f            ;; debug-validate?
              #f            ;; debug-analyze?
              #f            ;; debug-codegen?
              (and (getenv "CREST_DEBUG_MATCH") #t)))))  ;; debug-matching?
    (fields
     (mutable pattern-type)          ;; Phase 1: 'conversion or 'rewrite
     (mutable function-name)         ;; Phase 1: syntax identifier
     (mutable param-op)              ;; Phase 1: syntax identifier
     (mutable param-operands-ref)    ;; Phase 1: syntax identifier (conversion only)
     (mutable param-rewriter)        ;; Phase 1: syntax identifier
     (mutable param-type-converter)  ;; Phase 1: syntax identifier (conversion only)
     (mutable root-var)              ;; Phase 1: syntax identifier — :rewrite %root-var
     (mutable match)                 ;; Phase 1: list → Phase 2: vector of ast-match-expand
     (mutable match-analysis)        ;; Phase 3 (analyze): ast-match-analysis — bindings + actions

     (mutable rewrite)          ;; Phase 1 (parse): list of ast-operation-expand - rewrite operations
     ;; Operations to construct when pattern matches
     ;; Contains: list of ast-operation-expand records

     (mutable then-let)            ;; Phase 1 (parse): list of ast-then-let-binding-expand - constraint bindings
     ;; Additional computed bindings for rewrite
     ;; Contains: list of ast-then-let-binding-expand records

     (mutable debug-parse?)     ;; Phase 1 (parse): boolean - :debug-parse flag
     ;; When true, codegen outputs parsed AST as datum

     (mutable debug-validate?)  ;; Phase 1 (parse): boolean - :debug-validate flag
     ;; When true, codegen outputs validated AST as datum

     (mutable debug-analyze?)   ;; Phase 1 (parse): boolean - :debug-analyze flag
     ;; When true, codegen outputs match-actions as datum

     (mutable debug-codegen?)   ;; Phase 1 (parse): boolean - :debug-codegen flag
     ;; When true, codegen outputs generated code as quoted datum

     (mutable debug-matching?)))

  ;;-----------------------------------------------------------------------
  ;; MATCH-LEVEL RECORD: ast-match-expand (child of ast-pattern-expand)
  ;;-----------------------------------------------------------------------
  ;;
  ;; Used by: ast-pattern-expand (match field)
  ;;
  ;; Represents a single operation to match in the pattern.
  ;; Corresponds to one line in the :if-match clause.
  ;;
  ;; Contains:
  ;;   - operands: list of ast-operand records
  ;;
  ;; Example DSL input (single result):
  ;;   (%b = "op2" (%a) () : (!t2) -> !t3)
  ;;
  ;; Example DSL input (multiple results):
  ;;   ((%a %b) = "op2" (%x) () : (!t) -> (!t1 !t2))
  ;;
  (define-record-type (ast-match-expand make-ast-match-expand ast-match-expand?)
    (fields
     (immutable result-var)   ;; Phase 1 (parse): list of syntax identifiers — always a proper list.
     ;;   Parse normalises both single and multi-result at construction time:
     ;;     %out      →  (#'%out)
     ;;     (%a %b)   →  (#'%a #'%b)

     (immutable op-name)      ;; Phase 1 (parse): normalized string — always a Scheme string.
     ;;   Parse accepts string literal or symbol, converts to string immediately:
     ;;     "onnx.Cast"  →  "onnx.Cast"
     ;;     onnx.Cast    →  "onnx.Cast"
     ;;   Used directly for string comparison in validate, analyze, and codegen.
     ;;   Source location for CREST_DEBUG_MATCH is taken from result-var instead.

     (immutable operands)     ;; Phase 1 (parse): list of ast-operand records (flattened)
     ;; Phase 3 (analyze): used to generate operand binding actions
     ;;   [ast-operand(':required, #'%x), ast-operand(':optional, #'%y), ...]

     (immutable where-expr))) ;; Phase 1 (parse): syntax object - pure Scheme guard expression
  ;; Executes after matching this operation (early return on failure)
  ;; Default: #'#f (no guard, always succeeds)
  ;; Example: #'(let ([$ks (mlir-operation-get-attr %a "kernel_shape")])
  ;;             (and $ks (is-1x1-kernel? $ks)))
  ;; Can access: matched result-var, operands, any previously bound vars

  ;;-----------------------------------------------------------------------
  ;; OPERAND-LEVEL RECORD: ast-operand (child of ast-match-expand)
  ;;-----------------------------------------------------------------------
  ;;
  ;; Used by: ast-match-expand (operands field)
  ;;
  ;; Represents a single operand in a match operation with its kind tag.
  ;; The (:optional ...) and (:variadic ...) groups in the DSL syntax are
  ;; flattened during parsing — each variable gets its own record.
  ;;
  ;; Example DSL input: (%x (:optional %y %z) %w (:variadic %rest))
  ;; Phase 1 (parse): Flattened to list of ast-operand records:
  ;;   [ast-operand('required, #'%x),
  ;;    ast-operand('optional, #'%y),
  ;;    ast-operand('optional, #'%z),
  ;;    ast-operand('required, #'%w),
  ;;    ast-operand('variadic, #'%rest)]
  ;;
  ;; When kind is :optional or :variadic, the matched op must carry an
  ;; operandSegmentSizes DenseI32ArrayAttr — without it CREST cannot determine
  ;; group boundaries and the match returns #f.
  ;;
  (define-record-type (ast-operand make-ast-operand ast-operand?)
    (fields
     (immutable kind)         ;; Phase 1 (parse): keyword symbol ':required, ':optional, or ':variadic
     (immutable var)))        ;; Phase 1 (parse): syntax identifier (e.g., #'%x)

  ;;-----------------------------------------------------------------------
  ;; WHERE-BINDING-LEVEL RECORD: ast-then-let-binding-expand (child of ast-pattern-expand)
  ;;-----------------------------------------------------------------------
  ;;
  ;; Used by: ast-pattern-expand (where field)
  ;;
  ;; Represents a computed binding in the :where clause.
  ;; Used to compute additional values needed for rewrite.
  ;;
  ;; Example DSL input:
  ;;   :where ((!new-type (compute-type !old-type))
  ;;           (%ctx (get-context)))
  ;;
  (define-record-type (ast-then-let-binding-expand make-ast-then-let-binding-expand ast-then-let-binding-expand?)
    (fields
     (mutable var)            ;; Phase 1 (parse): syntax identifier - variable to bind
     ;; Example: #'!new-type or #'%ctx

     (mutable expr)))         ;; Phase 1 (parse): syntax expression - Scheme expression to evaluate
  ;; Example: #'(compute-type !old-type)
  ;; Not used by codegen; begin-mlir-code parses the raw rewrite syntax directly.

  ;;-----------------------------------------------------------------------
  ;; REWRITE-OPERATION-LEVEL RECORD: ast-operation-expand (child of ast-pattern-expand)
  ;;-----------------------------------------------------------------------
  ;;
  ;; Used by: ast-pattern-expand (rewrite field), ast-block-expand (operations field)
  ;;
  ;; Represents a single operation to construct in the rewrite.
  ;; Corresponds to one line in the :rewrite :with clause.
  ;;
  ;; Contains:
  ;;   - regions: list of ast-region-expand records
  ;;
  ;; Example DSL input:
  ;;   (%out = "arith.addi" (%x %y) :attrs [] -> !i32)
  ;;
  ;; Field order matches MLIR generic operation syntax:
  ;;   result = op-name (operands) :regions (...) :attrs [...] -> result-types
  ;;
  ;; Note: No input-types field. Input types are implicit in operand Values
  ;;       (each Value has .getType()). Only result types need to be specified.
  ;;
  (define-record-type (ast-operation-expand make-ast-operation-expand ast-operation-expand?)
    (fields
     (mutable result-var)     ;; Phase 1 (parse): syntax identifier or list - result variable(s)
     ;; Example: #'%out for single result
     ;; Example: #'(%a %b) for multiple results
     ;; Empty #'() for operations with no results

     (mutable op-name)        ;; Phase 1 (parse): syntax string - operation name to construct
     ;; Example: #'"arith.addi"

     (mutable operands)       ;; Phase 1 (parse): syntax list - operand expressions
     ;; Example: #'(%x) means pass bound variable %x
     ;; Operands must be bound by match or where clauses

     (mutable regions)        ;; Phase 1 (parse): list of ast-region-expand - nested regions
     ;; Example: control flow ops like scf.if have regions
     ;; Contains: list of ast-region-expand records
     ;; Not used by codegen; begin-mlir-code parses the raw rewrite syntax directly.

     (mutable attributes)     ;; Phase 1 (parse): syntax list - attribute expressions
     ;; Example: #'(("to" !t3)) for typed attribute
     ;; Not used by codegen; begin-mlir-code parses the raw rewrite syntax directly.

     (mutable result-types))) ;; Phase 1 (parse): syntax - result type expression(s)
  ;; Example: #'!t3 for single result type
  ;; Example: #'(!t1 !t2) for multiple result types
  ;; Not used by codegen; begin-mlir-code parses the raw rewrite syntax directly.

  ;;-----------------------------------------------------------------------
  ;; REGION-LEVEL RECORD: ast-region-expand (child of ast-operation-expand)
  ;;-----------------------------------------------------------------------
  ;;
  ;; Used by: ast-operation-expand (regions field)
  ;;
  ;; Represents a region in MLIR (a list of blocks).
  ;; Used by operations like scf.if, scf.while that contain nested code.
  ;;
  ;; Contains:
  ;;   - blocks: list of ast-block-expand records
  ;;
  (define-record-type (ast-region-expand make-ast-region-expand ast-region-expand?)
    (fields
     (mutable blocks)))       ;; Phase 1 (parse): list of ast-block-expand
  ;; Each region contains one or more blocks
  ;; Contains: list of ast-block-expand records

  ;;-----------------------------------------------------------------------
  ;; BLOCK-LEVEL RECORD: ast-block-expand (child of ast-region-expand)
  ;;-----------------------------------------------------------------------
  ;;
  ;; Used by: ast-region-expand (blocks field)
  ;;
  ;; Represents a block in MLIR (a sequence of operations with a label).
  ;; Blocks can take arguments like function parameters.
  ;;
  ;; Contains:
  ;;   - operations: list of ast-operation-expand records (recursive)
  ;;
  ;; Example DSL input:
  ;;   (^bb0 ((%arg0 : !t1) (%arg1 : !t2))
  ;;     (%sum = "arith.addi" (%arg0 %arg1) -> !t1)
  ;;     ("scf.yield" (%sum) -> ()))
  ;;
  (define-record-type (ast-block-expand make-ast-block-expand ast-block-expand?)
    (fields
     (mutable label)          ;; Phase 1 (parse): syntax identifier - block label
     ;; Example: #'^bb0 (^ prefix is convention)

     (mutable arguments)      ;; Phase 1 (parse): list of (var type) syntax pairs
     ;; Example: ((#'%arg0 #'!t1) (#'%arg1 #'!t2))
     ;; Block arguments are like function parameters

     (mutable operations)))   ;; Phase 1 (parse): list of ast-operation-expand
  ;; Operations in this block (can be recursive - blocks in regions in ops)
  ;; Contains: list of ast-operation-expand records (recursive)

  ;;-----------------------------------------------------------------------
  ;; SCHEME-BINDING RECORD: ast-scheme-binding-expand
  ;;-----------------------------------------------------------------------
  ;;
  ;; Represents a Scheme escape inside a :rewrite :with clause.
  ;; Discriminated from ast-operation-expand by the token after =:
  ;;   string or symbol after = → MLIR op (ast-operation-expand)
  ;;   list after =            → Scheme expression (ast-scheme-binding-expand)
  ;;
  ;; Examples:
  ;;   (%s = (when (pred? %r) (set-attr! %r "x" 1)))
  ;;   (_ = (log-debug "created"))
  ;;
  (define-record-type (ast-scheme-binding-expand make-ast-scheme-binding-expand ast-scheme-binding-expand?)
    (fields
     (mutable var)    ;; Phase 1 (parse): syntax — %var, list of %vars, _ or void (discard)
     (mutable expr))) ;; Phase 1 (parse): syntax — the raw Scheme expression (list form)
  )
