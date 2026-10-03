#!r6rs
(library (mlir ddr keywords)
  (export :if-match :then-let :rewrite :with :where
          :debug-parse :debug-validate :debug-analyze :debug-codegen :debug-matching
          = : -> :region :regions
          :index :any
          :current-op :attr
          :optional :variadic)
  (import (except (rnrs) =))

  ;; Define keywords as syntax (for cross-library hygiene)
  (define-syntax :if-match (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :then-let (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :rewrite (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :with (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :where (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :debug-parse (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :debug-validate (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :debug-analyze (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :debug-codegen (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :debug-matching (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax = (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax : (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax -> (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :region (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :regions (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :index   (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  (define-syntax :any        (lambda (x) (syntax-violation 'pattern-keyword "misplaced aux keyword" x)))
  ;; :current-op — inside a :where clause, refers to the currently matched sub-op.
  ;; Replaced syntactically by the DDR codegen; never evaluated as Scheme.
  (define-syntax :current-op (lambda (x) (syntax-violation 'pattern-keyword "misplaced :current-op (only valid inside DDR :where)" x)))
  ;; :attr — (:attr "name") or (:attr "name" :type) in a :where clause.
  ;; Fetches the named attribute from :current-op; raises an error if absent
  ;; (caught by the guard wrapping in generate-check-code → match failure).
  (define-syntax :attr       (lambda (x) (syntax-violation 'pattern-keyword "misplaced :attr (only valid inside DDR :where)" x)))
  ;; :optional — (:optional %var ...) in an operand list marks optional operands.
  ;; Each %var is bound to the operand value if present, left unbound if absent.
  ;; Presence is detected via mlir-operation-num-operands at match time.
  (define-syntax :optional   (lambda (x) (syntax-violation 'pattern-keyword "misplaced :optional (only valid inside DDR operand list)" x)))
  ;; :variadic — (:variadic %rest) in an operand list marks a variadic tail.
  ;; Parsed but not yet implemented in analyze/codegen.
  (define-syntax :variadic   (lambda (x) (syntax-violation 'pattern-keyword "misplaced :variadic (only valid inside DDR operand list)" x)))
)
