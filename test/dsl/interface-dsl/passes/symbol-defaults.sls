;; Calls the methods of SymbolOpInterface on ops that give no clause, and on one that overrides two.
(import (only (mlir Support WalkResult) mlir::WalkResult::advance)
        (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR MLIRContext)
        (mlir IR OwningOpRef)
        (mlir IR DialectRegistry)
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
  ;; LEAK WARNING: what this makes (the context, the module, the builder) lives in a with- scope and is
  ;; freed when the scope ends. A raw MLIRContext::new, ModuleOp::create or parseSourceFile result that is
  ;; never freed leaked, and exit inside a scope skips the cleanup: raise, and exit at the top (%%quit).
  (let* ([args (command-line-arguments)])
    (with-DialectRegistry reg ()
      (with-MLIRContext ctx (reg)
        (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
        (load-scheme-dialect! ctx "symdefaults" "passes/symdefaults")
        (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car args))
          (when (zero? module)
            (display "Failed to parse\n" (current-error-port))
            (%%quit 1))
          (with-current-MLIRContext ctx
            (let ([found '()])
              (mlir::Operation::walk
               module
               (lambda (op)
                 (let ([name (mlir::Operation::getName op)])
                   (when (member name '("symdefaults.sym" "symdefaults.overriding"))
                     (set! found (cons op found))))
                 #t mlir::WalkResult::advance))
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
                     (yes/no (mlir::SymbolOpInterface::replaceAllSymbolUses plain (mlir::StringAttr::get ctx "other") module)))))))))))

;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it.
(define (%%quit code)
  (raise (list 'exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'exit)) (exit (cadr e))])
  (main))
