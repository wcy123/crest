;; User-facing DSL for defining MLIR dialects
;; Macros that create semantic model records

(library (mlir codegen dialect-dsl)
  (export define-dialect)

  (import (chezscheme)
          (mlir codegen semantic-model))

  ;; Main dialect definition macro with full feature support
  (define-syntax define-dialect
    (syntax-rules (:name :cpp-namespace :description :depends-on
                   :use-default-attr-printer :use-default-type-printer
                   :has-constant-materializer :has-canonicalizer
                   :has-op-attr-verify :has-region-arg-attr-verify
                   :has-region-result-attr-verify :has-non-default-destructor
                   :has-op-interface-fallback :extra-class-decl)

      ;; Minimal form (only required fields)
      [(_ :name name-str
          :cpp-namespace ns-str
          :description desc-str
          :depends-on (deps ...))
       (make-dialect
         name-str ns-str desc-str (list deps ...)
         #t #t  ; default: use default attr/type printer
         #f #f #f #f #f #f #f  ; all capabilities off
         #f)]  ; no extra-class-decl

      ;; TODO: Add keyword argument handler for optional fields
      ;; For now, require explicit make-dialect calls for advanced features
    )))
