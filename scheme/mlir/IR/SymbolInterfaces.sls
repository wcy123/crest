#!r6rs
;; Mirrors mlir/IR/SymbolInterfaces.h
(library (mlir IR SymbolInterfaces)
  (export mlir::SymbolOpInterface
          mlir::SymbolOpInterface::getInterfaceID
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
  (import (chezscheme)
          (crest callback)
          (for (crest interface) expand)
          (only (mlir IR Operation)
                mlir::Operation::getAttr
                mlir::Operation::setAttr!
                mlir::Operation::removeAttr
                mlir::Operation::getContext)
          (only (mlir IR OpImplementation) mlir::StringAttr::getValue)
          (only (mlir IR BuiltinAttributes) mlir::StringAttr::get)
          (mlir IR SymbolInterfaces ffi))

  ;; What MLIR does for an op that does not override the method (SymbolInterfaces.td), written here
  ;; so that nothing hides in C++: the name is the "sym_name" attribute and the visibility the
  ;; "sym_visibility" attribute, public when it is absent. The visibility is a number: 0 public,
  ;; 1 private, 2 nested.
  (define (%%default-get-name op) (or (mlir::Operation::getAttr op "sym_name") 0))

  (define (%%default-set-name op name) (mlir::Operation::setAttr! op "sym_name" name))

  (define (%%default-get-visibility op)
    (let ([attr (mlir::Operation::getAttr op "sym_visibility")])
      (if (not attr)
          0
          (let ([text (mlir::StringAttr::getValue attr)])
            (cond [(string=? text "public") 0]
                  [(string=? text "private") 1]
                  [(string=? text "nested") 2]
                  [else (error 'sym_visibility "unknown visibility" text)])))))

  (define (%%default-set-visibility op visibility)
    (if (= visibility 0)
        (mlir::Operation::removeAttr op "sym_visibility")
        (mlir::Operation::setAttr!
         op "sym_visibility"
         (mlir::StringAttr::get (mlir::Operation::getContext op)
                                (if (= visibility 1) "private" "nested")))))

  ;; The other methods ask the op for its visibility with the interface, as MLIR does with the op.
  (define (%%default-is-nested op) (= (mlir::SymbolOpInterface::getVisibility op) 2))
  (define (%%default-is-private op) (= (mlir::SymbolOpInterface::getVisibility op) 1))
  (define (%%default-is-public op) (= (mlir::SymbolOpInterface::getVisibility op) 0))
  (define (%%default-set-nested op) (mlir::SymbolOpInterface::setVisibility op 2))
  (define (%%default-set-private op) (mlir::SymbolOpInterface::setVisibility op 1))
  (define (%%default-set-public op) (mlir::SymbolOpInterface::setVisibility op 0))
  (define (%%default-false op) #f)

  ;; A symbol can be discarded when it has no uses, unless it is public.
  (define (%%default-can-discard-on-use-empty op)
    (not (= (mlir::SymbolOpInterface::getVisibility op) 0)))

  ;; The clause answers a boolean, the slot a bool: 1 or 0.
  (define (%%bool clause)
    (lambda arguments (if (apply clause arguments) 1 0)))

  ;; An entry of the :interfaces clause of define-op:
  ;;   (mlir::SymbolOpInterface clause ...)
  ;; with a clause (method (op ...) body ...) for any of the methods: getNameAttr (the StringAttr),
  ;; setName (op name), getVisibility (0, 1 or 2), isNested, isPrivate, isPublic, setVisibility
  ;; (op visibility), setNested, setPrivate, setPublic, symbolKnownUseEmpty, replaceAllSymbolUses,
  ;; isOptionalSymbol, canDiscardOnUseEmpty, isDeclaration, or getSymbolUses (not in Scheme: see
  ;; below). MLIR has a default for every method, and an op that does not give a clause gets it;
  ;; getSymbolUses, symbolKnownUseEmpty and replaceAllSymbolUses are those of SymbolTable, a C
  ;; function that CREST ships, because a use range is not something Scheme can answer.
  (define-syntax mlir::SymbolOpInterface
    (lambda (stx)
      (op-interface-expand
       stx 'mlir::SymbolOpInterface #'(mlir::SymbolOpInterface::getInterfaceID)
       #'((getNameAttr (uptr) object #f %%default-get-name ())
          (setName (uptr uptr) void #f %%default-set-name ())
          (getVisibility (uptr) int #f %%default-get-visibility ())
          (isNested (uptr) unsigned-8 %%bool %%default-is-nested ())
          (isPrivate (uptr) unsigned-8 %%bool %%default-is-private ())
          (isPublic (uptr) unsigned-8 %%bool %%default-is-public ())
          (setVisibility (uptr int) void #f %%default-set-visibility ())
          (setNested (uptr) void #f %%default-set-nested ())
          (setPrivate (uptr) void #f %%default-set-private ())
          (setPublic (uptr) void #f %%default-set-public ())
          (getSymbolUses (uptr uptr) uptr #f (cpp (%crest::SymbolOpInterface::getSymbolUses)) ())
          (symbolKnownUseEmpty (uptr uptr) unsigned-8 %%bool
                               (cpp (%crest::SymbolOpInterface::symbolKnownUseEmpty)) ())
          (replaceAllSymbolUses (uptr uptr uptr) logical-result #f
                                (cpp (%crest::SymbolOpInterface::replaceAllSymbolUses)) ())
          (isOptionalSymbol (uptr) unsigned-8 %%bool %%default-false ())
          (canDiscardOnUseEmpty (uptr) unsigned-8 %%bool %%default-can-discard-on-use-empty ())
          (isDeclaration (uptr) unsigned-8 %%bool %%default-false ())))))

  (define mlir::SymbolOpInterface::getInterfaceID
    %mlir::SymbolOpInterface::getInterfaceID)

  (define (mlir::SymbolOpInterface::getNameAttr op)
    (%mlir::SymbolOpInterface::getNameAttr op))

  (define (mlir::SymbolOpInterface::setName op name)
    (%mlir::SymbolOpInterface::setName op name))

  (define (mlir::SymbolOpInterface::getVisibility op)
    (%mlir::SymbolOpInterface::getVisibility op))

  (define (mlir::SymbolOpInterface::isNested op)
    (= 1 (%mlir::SymbolOpInterface::isNested op)))

  (define (mlir::SymbolOpInterface::isPrivate op)
    (= 1 (%mlir::SymbolOpInterface::isPrivate op)))

  (define (mlir::SymbolOpInterface::isPublic op)
    (= 1 (%mlir::SymbolOpInterface::isPublic op)))

  (define (mlir::SymbolOpInterface::setVisibility op visibility)
    (%mlir::SymbolOpInterface::setVisibility op visibility))

  (define (mlir::SymbolOpInterface::setNested op)
    (%mlir::SymbolOpInterface::setNested op))

  (define (mlir::SymbolOpInterface::setPrivate op)
    (%mlir::SymbolOpInterface::setPrivate op))

  (define (mlir::SymbolOpInterface::setPublic op)
    (%mlir::SymbolOpInterface::setPublic op))

  (define (mlir::SymbolOpInterface::symbolKnownUseEmpty op from)
    (= 1 (%mlir::SymbolOpInterface::symbolKnownUseEmpty op from)))

  ;; True when the uses of the symbol within `from` were all replaced by the symbol `new-name`.
  (define (mlir::SymbolOpInterface::replaceAllSymbolUses op new-name from)
    (= 1 (%mlir::SymbolOpInterface::replaceAllSymbolUses op new-name from)))

  (define (mlir::SymbolOpInterface::isOptionalSymbol op)
    (= 1 (%mlir::SymbolOpInterface::isOptionalSymbol op)))

  (define (mlir::SymbolOpInterface::canDiscardOnUseEmpty op)
    (= 1 (%mlir::SymbolOpInterface::canDiscardOnUseEmpty op)))

  (define (mlir::SymbolOpInterface::isDeclaration op)
    (= 1 (%mlir::SymbolOpInterface::isDeclaration op)))

  ) ;; end library (mlir IR SymbolInterfaces)
