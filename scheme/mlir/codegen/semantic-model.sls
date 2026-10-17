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
    dialect-use-default-attr-printer
    dialect-use-default-type-printer
    dialect-has-constant-materializer
    dialect-has-canonicalizer
    dialect-has-op-attr-verify
    dialect-has-region-arg-attr-verify
    dialect-has-region-result-attr-verify
    dialect-has-non-default-destructor
    dialect-has-op-interface-fallback
    dialect-extra-class-decl)

  (import (chezscheme))

  ;; Dialect definition - COMPLETE feature set
  (define-record-type dialect
    (fields
      ;; Basic properties
      (immutable name)                         ; string: "hip"
      (immutable cpp-namespace)                ; string: "::mlir::hip"
      (immutable description)                  ; string: documentation
      (immutable dependent-dialects)           ; list of strings

      ;; Attribute/Type printer/parser
      (immutable use-default-attr-printer)     ; bool: useDefaultAttributePrinterParser
      (immutable use-default-type-printer)     ; bool: useDefaultTypePrinterParser

      ;; Dialect capabilities
      (immutable has-constant-materializer)    ; bool: hasConstantMaterializer
      (immutable has-canonicalizer)            ; bool: hasCanonicalizer
      (immutable has-op-attr-verify)           ; bool: hasOperationAttrVerify
      (immutable has-region-arg-attr-verify)   ; bool: hasRegionArgAttrVerify
      (immutable has-region-result-attr-verify); bool: hasRegionResultAttrVerify
      (immutable has-non-default-destructor)   ; bool: hasNonDefaultDestructor
      (immutable has-op-interface-fallback)    ; bool: hasOperationInterfaceFallback

      ;; Extra code
      (immutable extra-class-decl)             ; string or #f: extraClassDeclaration
    )))
