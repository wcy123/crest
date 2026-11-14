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

(library (crest pattern-dsl ast)
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

          ast-then-let-binding-expand make-ast-then-let-binding-expand ast-then-let-binding-expand?
          ast-then-let-binding-expand-var ast-then-let-binding-expand-var-set!
          ast-then-let-binding-expand-expr ast-then-let-binding-expand-expr-set!

          ast-operand make-ast-operand ast-operand?
          ast-operand-kind
          ast-operand-var

          ;; begin-mlir-code v2 parsed op record
          ast-emit-op make-ast-emit-op ast-emit-op?
          ast-emit-op-result-vars
          ast-emit-op-op-name
          ast-emit-op-op-name-stx
          ast-emit-op-operands
          ast-emit-op-attr-setters
          ast-emit-op-region-fills
          ast-emit-op-loc-override
          ast-emit-op-result-types)
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
  ;; └── rewrite: the raw syntax of :rewrite :with (begin-mlir-code parses it)
  ;;
  ;; Reading flow: Start at root (pattern definition), drill down into
  ;; match operations and operand details.
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
  ;;   - rewrite: the raw syntax of :rewrite :with, as a list (begin-mlir-code parses it)
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

     (mutable rewrite)          ;; Phase 1 (parse): list of syntax objects - the body of :rewrite :with
     ;; Kept as raw syntax: begin-mlir-code parses it when the pattern is generated

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
  ;; EMIT-OP RECORD: ast-emit-op (used by begin-mlir-code v2 flat parser)
  ;;-----------------------------------------------------------------------
  ;;
  ;; Represents one parsed op-form returned by parse-next.
  ;; parse-next scans the flat begin-mlir-code argument list and detects:
  ;;   r = op.name (ops) ...      single-result
  ;;   (r0 r1) = op.name (ops)    multi-result
  ;;   op.name (ops) ...          no-result (statement)
  ;;
  (define-record-type (ast-emit-op make-ast-emit-op ast-emit-op?)
    (fields
     (immutable result-vars)   ; list of syntax identifiers; empty for no-result ops
     (immutable op-name)       ; string — e.g. "toy.constant"
     (immutable op-name-stx)   ; syntax object carrying source location annotation
     (immutable operands)      ; syntax expr — (list v1 v2 ...)
     (immutable attr-setters)  ; list of (lambda (state-stx) → setter-stx)
     (immutable region-fills)  ; list of (lambda (new-op-stx) → fill-stx)
     (immutable loc-override)  ; syntax or #f
     (immutable result-types))) ; syntax list — empty for no-result
  )
