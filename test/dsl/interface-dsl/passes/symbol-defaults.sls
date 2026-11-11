;; Calls the methods of SymbolOpInterface on ops that give no clause, and on one that overrides two.
(import (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR MLIRContext)
        (only (mlir IR OpImplementation) mlir::StringAttr::getValue)
        (only (mlir IR SymbolInterfaces)
              mlir::SymbolOpInterface::getNameAttr
              mlir::SymbolOpInterface::setName
              mlir::SymbolOpInterface::getVisibility
              mlir::SymbolOpInterface::isNested
              mlir::SymbolOpInterface::isPrivate
              mlir::SymbolOpInterface::isPublic
              mlir::SymbolOpInterface::setVisibility
              mlir::SymbolOpInterface::setNested
              mlir::SymbolOpInterface::setPrivate
              mlir::SymbolOpInterface::setPublic
              mlir::SymbolOpInterface::symbolKnownUseEmpty
              mlir::SymbolOpInterface::replaceAllSymbolUses
              mlir::SymbolOpInterface::isOptionalSymbol
              mlir::SymbolOpInterface::canDiscardOnUseEmpty
              mlir::SymbolOpInterface::isDeclaration)
        (only (mlir IR BuiltinAttributes) mlir::StringAttr::get))

(define (say . parts) (for-each display parts) (newline))
(define (yes/no b) (if b 'yes 'no))
(define visibilities '#(public private nested))

(define (main)
  (let* ([args (command-line-arguments)]
         [ctx (mlir::MLIRContext::new)]
         [_   (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
         [_   (load-scheme-dialect! ctx "symdefaults" "passes/symdefaults")]
         [module (mlir::parseSourceFile ctx (car args))])
    (when (zero? module)
      (display "Failed to parse\n" (current-error-port))
      (exit 1))
    (with-current-MLIRContext ctx
      (let ([found '()])
        (mlir::Operation::walk
         module
         (lambda (op)
           (let ([name (mlir::Operation::getName op)])
             (when (member name '("symdefaults.sym" "symdefaults.overriding"))
               (set! found (cons op found))))
           #t))
        (let* ([ops (reverse found)]
               [plain (car ops)] [private (cadr ops)] [nested (caddr ops)] [over (cadddr ops)])
          (for-each
           (lambda (op)
             (say (mlir::StringAttr::getValue (mlir::SymbolOpInterface::getNameAttr op))
                  ": " (vector-ref visibilities (mlir::SymbolOpInterface::getVisibility op))
                  " nested=" (yes/no (mlir::SymbolOpInterface::isNested op))
                  " private=" (yes/no (mlir::SymbolOpInterface::isPrivate op))
                  " public=" (yes/no (mlir::SymbolOpInterface::isPublic op))
                  " discard=" (yes/no (mlir::SymbolOpInterface::canDiscardOnUseEmpty op))
                  " declaration=" (yes/no (mlir::SymbolOpInterface::isDeclaration op))
                  " optional=" (yes/no (mlir::SymbolOpInterface::isOptionalSymbol op))))
           (list plain private nested over))
          (mlir::SymbolOpInterface::setPrivate plain)
          (say "after setPrivate: " (vector-ref visibilities (mlir::SymbolOpInterface::getVisibility plain))
               " attribute=" (yes/no (mlir::Operation::getAttr plain "sym_visibility")))
          (mlir::SymbolOpInterface::setPublic plain)
          (say "after setPublic: " (vector-ref visibilities (mlir::SymbolOpInterface::getVisibility plain))
               " attribute=" (yes/no (mlir::Operation::getAttr plain "sym_visibility")))
          (mlir::SymbolOpInterface::setNested plain)
          (say "after setNested: " (vector-ref visibilities (mlir::SymbolOpInterface::getVisibility plain)))
          (mlir::SymbolOpInterface::setVisibility plain 1)
          (say "after setVisibility 1: " (vector-ref visibilities (mlir::SymbolOpInterface::getVisibility plain)))
          (mlir::SymbolOpInterface::setName plain (mlir::StringAttr::get ctx "renamed"))
          (say "after setName: " (mlir::StringAttr::getValue (mlir::SymbolOpInterface::getNameAttr plain)))
          (say "no uses in the module: " (yes/no (mlir::SymbolOpInterface::symbolKnownUseEmpty plain module)))
          (say "rename succeeds: "
               (yes/no (mlir::SymbolOpInterface::replaceAllSymbolUses plain (mlir::StringAttr::get ctx "other") module))))))))

(main)
