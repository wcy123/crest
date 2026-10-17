#!chezscheme
;; Dialect code generation
;; Generates C++ declarations and definitions from dialect records

(library (mlir codegen dialect-gen)
  (export
    generate-dialect-decl
    generate-dialect-def
    cpp-class-name)

  (import (chezscheme)
          (mlir codegen semantic-model)
          (mlir codegen cpp-printer))

  ;; Generate dialect class name from dialect name
  ;; "hip" -> "HipDialect"
  (define (cpp-class-name dialect)
    (let ([name (dialect-name dialect)])
      (string-append
       (string-upcase (substring name 0 1))
       (substring name 1 (string-length name))
       "Dialect")))

  ;; Generate dialect class declaration (.h.inc)
  (define (generate-dialect-decl dialect)
    (let ([class-name (cpp-class-name dialect)]
          [namespace-str (dialect-cpp-namespace dialect)]
          [name-str (dialect-name dialect)]
          [deps (dialect-dependent-dialects dialect)]
          [extra (dialect-extra-class-decl dialect)]
          [use-attr-printer (dialect-use-default-attr-printer dialect)]
          [use-type-printer (dialect-use-default-type-printer dialect)])

      `(class ,class-name : public ::mlir::Dialect {
                                                    ,(comment (string-append "MLIR Dialect: " name-str))

                                                    (method public "explicit" ,class-name
                                                            ((::mlir::MLIRContext *context))
                                                            #f)

                                                    (method public static constexpr ::llvm::StringLiteral
                                                            getDialectNamespace
                                                            ()
                                                            const
                                                            (return (::llvm::StringLiteral (string-lit ,name-str))))

                                                    ,@(if use-attr-printer
                                                          '((method public void printAttribute
                                                                    ((::mlir::Attribute attr)
                                                                     (::mlir::DialectAsmPrinter &os))
                                                                    const override
                                                                    #f))
                                                          '())

                                                    ,@(if use-type-printer
                                                          '((method public void printType
                                                                    ((::mlir::Type type)
                                                                     (::mlir::DialectAsmPrinter &os))
                                                                    const override
                                                                    #f))
                                                          '())

                                                    ,@(if extra
                                                          (list extra)
                                                          '())
                                                    })))

  ;; Generate dialect implementation (.cpp.inc)
  (define (generate-dialect-def dialect)
    (let ([class-name (cpp-class-name dialect)]
          [namespace-str (dialect-cpp-namespace dialect)]
          [name-str (dialect-name dialect)]
          [deps (dialect-dependent-dialects dialect)]
          [desc (dialect-description dialect)])

      `(namespace ,(string->symbol namespace-str) {

                                                   ,(comment (string-append "Dialect: " name-str))
                                                   ,(comment desc)

                                                   (function "void" ,class-name
                                                             ((::mlir::MLIRContext *context))
                                                             (begin
                                                               ,@(map (lambda (dep)
                                                                        (list 'stmt
                                                                              (string-append "getContext()->getOrLoadDialect<"
                                                                                             dep
                                                                                             ">()")))
                                                                      deps)
                                                               (stmt "initialize()")))

                                                   (function "void" initialize
                                                             ()
                                                             (begin
                                                               ,(comment "Register operations")
                                                               ,(comment "Register types")
                                                               ,(comment "Register attributes")))
                                                   })))

  ;; Helper: create comment S-expression
  (define (comment text)
    `(comment ,text))
  )
