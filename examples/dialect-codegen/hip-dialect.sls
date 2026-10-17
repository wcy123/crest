;; Example: Define HIP dialect using CREST DSL

(import (chezscheme)
        (mlir codegen semantic-model)
        (mlir codegen dialect-dsl)
        (mlir codegen dialect-gen)
        (mlir codegen cpp-printer))

;; Define the HIP dialect
(define hip-dialect
  (define-dialect
    :name "hip"
    :cpp-namespace "::mlir::hip"
    :description "HIP dialect for AMD GPU operations targeting ROCm/HIP backends"
    :depends-on ("::mlir::arith::ArithDialect"
                 "::mlir::tensor::TensorDialect"
                 "::mlir::func::FuncDialect")))

;; Generate and print declaration
(display "=== HIP Dialect Declaration (.h.inc) ===\n")
(display (sexp->cpp (generate-dialect-decl hip-dialect)))
(display "\n\n")

;; Generate and print definition
(display "=== HIP Dialect Definition (.cpp.inc) ===\n")
(display (sexp->cpp (generate-dialect-def hip-dialect)))
(display "\n")
