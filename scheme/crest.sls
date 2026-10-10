#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest) — Public DDR (Dynamic Dialect Rewriting) API.
;;
;; CREST's DDR system lets you write MLIR rewrite patterns in Scheme.
;; Three macros form the public surface:
;;
;;   define-conversion-pattern   — dialect conversion (with TypeConverter)
;;   define-rewrite-pattern      — greedy rewrite (no type conversion)
;;   begin-mlir-code             — inline MLIR op emission DSL
;;
;;===----------------------------------------------------------------------===;;
;;
;; define-rewrite-pattern
;; ──────────────────────
;; Defines a greedy rewrite pattern (mlir::RewritePattern).
;;
;;   (define-rewrite-pattern (fn-name matched-op rewriter)
;;     :if-match
;;       %var = dialect.op (operands...) :where guard-expr
;;       ...
;;     :then-let
;;       ([binding expr] ...)
;;     :rewrite %root-var :with
;;       begin-mlir-code-body ...)
;;
;; :if-match    — structural match on the IR. Each line binds a %var to an
;;               SSA value or Operation*. `:where expr` adds a guard.
;;               Operand patterns like `%v = dialect.op (...)` also anchor
;;               the search to the defining op of that value.
;;
;; :then-let    — evaluated after a successful match, before the rewrite.
;;               Bindings are plain Scheme let* entries; can call helpers.
;;               `rewriter` and `matched-op` are in scope here.
;;
;; :rewrite %v :with body ...
;;               — `%v` is the root value to replace. `body ...` is one or
;;               more op-forms in begin-mlir-code DSL syntax. The last
;;               result replaces `%v`.
;;
;; Example:
;;   (define-rewrite-pattern (qadd-fusion op rewriter)
;;     :if-match
;;       %q = hip.quantize_linear (%ctx %sum %scale)
;;         :where (hip-splat-scale? %scale)
;;       %sum = hip.add (%ctx %dq_a %dq_b %init)
;;     :then-let ([!out-type (mlir::Value::getType %q)])
;;     :rewrite %q :with
;;       (%result = hip.qadd (%ctx %dq_a %dq_b %init)
;;         ("output_scale" = (hip-extract-splat-scale %scale) :f32)
;;         -> !out-type))
;;
;;===----------------------------------------------------------------------===;;
;;
;; define-conversion-pattern
;; ─────────────────────────
;; Like define-rewrite-pattern but for dialect conversion
;; (mlir::ConversionPattern / mlir::TypeConverter).
;;
;;   (define-conversion-pattern (fn-name matched-op rewriter)
;;     :if-match   ...
;;     :then-let   ...
;;     :rewrite %v :with body ...)
;;
;; The matched operands are already type-converted. The generated callback
;; signature is `(fn-name op operands rewriter type-converter)`. Suitable
;; for registration with `add-conversion-pattern`.
;;
;;===----------------------------------------------------------------------===;;
;;
;; begin-mlir-code
;; ───────────────
;; Inline DSL for emitting MLIR operations. Takes an explicit builder context:
;;
;;   (begin-mlir-code ctx op-form ...)
;;
;; ctx may be a CrestRef<RewriterBase> (from a pattern callback) or a
;; CrestOwned<OpBuilder> (from with-OpBuilder or a ^bb0 block). The correct
;; C++ create binding is selected automatically at runtime.
;;
;; op-form syntax:
;;
;;   Single-result:
;;     (%var = dialect.op (operands...) modifiers... -> result-type)
;;
;;   Multi-result:
;;     ((%a %b) = dialect.op (operands...) modifiers... -> (type-a type-b))
;;
;;   Statement (no result):
;;     (dialect.op (operands...) modifiers...)
;;
;;   Scheme escape (arbitrary Scheme expression):
;;     (%var = scheme-expr)
;;
;; modifiers (between operands and ->):
;;   ("name" = val :f32)       — FloatAttr (f32)
;;   ("name" = val :i64)       — IntegerAttr (i64)
;;   ("name" = val :index)     — IntegerAttr (IndexType)
;;   ("name" = val :i32-array) — DenseI32ArrayAttr
;;   ("name" = val :i64-array) — DenseI64ArrayAttr
;;   ("name" = _   :unit)      — UnitAttr (presence-only flag; val is ignored)
;;   ("name" = val)            — val is a pre-built Attribute uptr
;;   (^bb0 ((arg : !type) ...) body ...)  — inline region block
;;
;; Operand conventions:
;;   %var        — SSA Value uptr
;;   !type-var   — filtered as result type, NOT added to operand list
;;   ,@list-expr — splices a runtime list into the operand list
;;
;; Source locations: each emitted op automatically receives a
;; mlir::FileLineColLoc derived from the Scheme source position of the
;; op name identifier, enabling precise error messages in MLIR diagnostics.
;;
;; Example:
;;   (begin-mlir-code rw
;;     (%init   = tensor.empty () -> !out-type)
;;     (%result = hip.qadd (%ctx %a %b %init)
;;       ("output_scale" = scale :f32)
;;       ("output_zp"    = zp    :i64)
;;       -> !out-type))
;;
;; Inside :rewrite :with, begin-mlir-code is implicit — the codegen wraps
;; the body automatically with the active rewriter.
;;
;;===----------------------------------------------------------------------===;;

(library (crest)
  (export define-conversion-pattern
          define-rewrite-pattern
          begin-mlir-code
          :if-match :then-let :rewrite :with :where
          :debug-parse :debug-validate :debug-analyze :debug-codegen
          = : -> :region :regions
          :any
          :current-op :attr
          :optional :variadic
          :index :i64 :f32 :i32-array :i64-array :unit
          make-unbound-value unbound-value?)
  (import (except (rnrs) =)
          (crest internal keywords)
          (for (only (crest internal rewrite) begin-mlir-code) expand)
          (for (crest internal keywords) expand)
          (for (crest internal ast) expand)
          (for (crest internal codegen) expand)
          (for (only (crest internal codegen) make-unbound-value unbound-value?) expand))

  (define-syntax define-conversion-pattern
    (lambda (stx) (run-pipeline stx 'conversion)))

  (define-syntax define-rewrite-pattern
    (lambda (stx) (run-pipeline stx 'rewrite)))

  ) ;; end library (crest)
