;; Toy language AST — Scheme representation
;; Mirrors mlir/examples/toy/Ch1/include/toy/AST.h
(library (toy ch1 ast)
  (export
    ;; Literals
    make-number-expr  number-expr?  number-expr-value
    make-literal-expr literal-expr? literal-expr-values literal-expr-dims
    ;; Variables and calls
    make-var-expr     var-expr?     var-expr-name
    make-call-expr    call-expr?    call-expr-callee call-expr-args
    ;; Binary operation
    make-binop-expr   binop-expr?   binop-expr-op binop-expr-lhs binop-expr-rhs
    ;; Statements
    make-return-stmt  return-stmt?  return-stmt-expr
    make-print-stmt   print-stmt?   print-stmt-arg
    make-var-decl     var-decl?     var-decl-name var-decl-type var-decl-init
    ;; Top-level
    make-prototype    prototype?    prototype-name prototype-args
    make-function     function?     function-proto function-body
    make-module       module?       module-functions)
  (import (chezscheme))

  (define-record-type number-expr  (fields value))
  (define-record-type literal-expr (fields values dims))  ; values: nested list, dims: list of ints
  (define-record-type var-expr     (fields name))
  (define-record-type call-expr    (fields callee args))
  (define-record-type binop-expr   (fields op lhs rhs))   ; op: symbol e.g. '*'
  (define-record-type return-stmt  (fields expr))
  (define-record-type print-stmt   (fields arg))
  (define-record-type var-decl     (fields name type init))  ; type: '() or (dim ...), init: expr
  (define-record-type prototype    (fields name args))
  (define-record-type function     (fields proto body))   ; body: list of stmts
  (define-record-type module       (fields functions)))   ; functions: list of function
