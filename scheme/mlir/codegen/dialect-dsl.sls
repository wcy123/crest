;; User-facing DSL for defining MLIR dialects
;; Macros that create semantic model records

(library (mlir codegen dialect-dsl)
  (export define-dialect)

  (import (chezscheme)
          (mlir codegen semantic-model))

  ;; Main dialect definition macro
  (define-syntax define-dialect
    (lambda (stx)
      (syntax-case stx (:name :cpp-namespace :description :depends-on :extra-class-decl)

        ;; Full form with all options
        [(_ :name name-str
            :cpp-namespace ns-str
            :description desc-str
            :depends-on (deps ...)
            :extra-class-decl extra-code)
         #'(make-dialect
             name-str
             ns-str
             desc-str
             (list deps ...)
             extra-code
             #t  ; use-default-attr-printer
             #t  ; use-default-type-printer
           )]

        ;; Minimal form (no extra-class-decl)
        [(_ :name name-str
            :cpp-namespace ns-str
            :description desc-str
            :depends-on (deps ...))
         #'(make-dialect
             name-str
             ns-str
             desc-str
             (list deps ...)
             #f  ; no extra-class-decl
             #t  ; use-default-attr-printer
             #t  ; use-default-type-printer
           )]))))
