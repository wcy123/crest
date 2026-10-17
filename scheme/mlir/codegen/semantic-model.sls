;; Mirrors MLIR dialect/operation semantic model
;; This is pure data - no code generation

(library (mlir codegen semantic-model)
  (export
    ;; Dialect record type
    make-dialect
    dialect?
    dialect-name
    dialect-cpp-namespace
    dialect-description
    dialect-dependent-dialects
    dialect-extra-class-decl
    dialect-use-default-attr-printer
    dialect-use-default-type-printer)

  (import (chezscheme))

  ;; Dialect definition
  (define-record-type dialect
    (fields
      (immutable name)                    ; string: "hip"
      (immutable cpp-namespace)           ; string: "::mlir::hip"
      (immutable description)             ; string: documentation
      (immutable dependent-dialects)      ; list of strings
      (immutable extra-class-decl)        ; string or #f: extra C++ code
      (immutable use-default-attr-printer) ; bool
      (immutable use-default-type-printer) ; bool
    )))
