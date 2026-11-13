#!r6rs
;; Mirrors mlir/IR/SymbolInterfaces.h
(library (mlir IR SymbolInterfaces ffi)
  (export %mlir::SymbolOpInterface::getInterfaceID
          %mlir::SymbolOpInterface::getNameAttr
          %mlir::SymbolOpInterface::setName
          %mlir::SymbolOpInterface::getVisibility
          %mlir::SymbolOpInterface::isNested
          %mlir::SymbolOpInterface::isPrivate
          %mlir::SymbolOpInterface::isPublic
          %mlir::SymbolOpInterface::setVisibility
          %mlir::SymbolOpInterface::setNested
          %mlir::SymbolOpInterface::setPrivate
          %mlir::SymbolOpInterface::setPublic
          %mlir::SymbolOpInterface::symbolKnownUseEmpty
          %mlir::SymbolOpInterface::replaceAllSymbolUses
          %mlir::SymbolOpInterface::isOptionalSymbol
          %mlir::SymbolOpInterface::canDiscardOnUseEmpty
          %mlir::SymbolOpInterface::isDeclaration
          %crest::SymbolOpInterface::getSymbolUses
          %crest::SymbolOpInterface::symbolKnownUseEmpty
          %crest::SymbolOpInterface::replaceAllSymbolUses)
  (import (chezscheme)
          (crest support foreign))

  ;; () -> uptr: the TypeID of the interface, as the address that the TypeID wraps.
  (define %mlir::SymbolOpInterface::getInterfaceID
    (crest-foreign-procedure "mlir::SymbolOpInterface::getInterfaceID" () uptr))

  ;; The methods of the interface on an op, through the Concept of the op.
  (define %mlir::SymbolOpInterface::getNameAttr
    (crest-foreign-procedure "mlir::SymbolOpInterface::getNameAttr" (uptr) uptr))

  (define %mlir::SymbolOpInterface::setName
    (crest-foreign-procedure "mlir::SymbolOpInterface::setName" (uptr uptr) void))

  ;; The visibility is a number: 0 public, 1 private, 2 nested.
  (define %mlir::SymbolOpInterface::getVisibility
    (crest-foreign-procedure "mlir::SymbolOpInterface::getVisibility" (uptr) int))

  (define %mlir::SymbolOpInterface::isNested
    (crest-foreign-procedure "mlir::SymbolOpInterface::isNested" (uptr) int))

  (define %mlir::SymbolOpInterface::isPrivate
    (crest-foreign-procedure "mlir::SymbolOpInterface::isPrivate" (uptr) int))

  (define %mlir::SymbolOpInterface::isPublic
    (crest-foreign-procedure "mlir::SymbolOpInterface::isPublic" (uptr) int))

  (define %mlir::SymbolOpInterface::setVisibility
    (crest-foreign-procedure "mlir::SymbolOpInterface::setVisibility" (uptr int) void))

  (define %mlir::SymbolOpInterface::setNested
    (crest-foreign-procedure "mlir::SymbolOpInterface::setNested" (uptr) void))

  (define %mlir::SymbolOpInterface::setPrivate
    (crest-foreign-procedure "mlir::SymbolOpInterface::setPrivate" (uptr) void))

  (define %mlir::SymbolOpInterface::setPublic
    (crest-foreign-procedure "mlir::SymbolOpInterface::setPublic" (uptr) void))

  (define %mlir::SymbolOpInterface::symbolKnownUseEmpty
    (crest-foreign-procedure "mlir::SymbolOpInterface::symbolKnownUseEmpty" (uptr uptr) int))

  (define %mlir::SymbolOpInterface::replaceAllSymbolUses
    (crest-foreign-procedure "mlir::SymbolOpInterface::replaceAllSymbolUses" (uptr uptr uptr) int))

  (define %mlir::SymbolOpInterface::isOptionalSymbol
    (crest-foreign-procedure "mlir::SymbolOpInterface::isOptionalSymbol" (uptr) int))

  (define %mlir::SymbolOpInterface::canDiscardOnUseEmpty
    (crest-foreign-procedure "mlir::SymbolOpInterface::canDiscardOnUseEmpty" (uptr) int))

  (define %mlir::SymbolOpInterface::isDeclaration
    (crest-foreign-procedure "mlir::SymbolOpInterface::isDeclaration" (uptr) int))

  ;; () -> uptr: the address of a C function that CREST ships for a slot that Scheme cannot write
  ;; (lib/Bindings/IR/SymbolInterfaces.cpp): what SymbolTable answers.
  (define %crest::SymbolOpInterface::getSymbolUses
    (crest-foreign-procedure "crest::SymbolOpInterface::getSymbolUses" () uptr))

  (define %crest::SymbolOpInterface::symbolKnownUseEmpty
    (crest-foreign-procedure "crest::SymbolOpInterface::symbolKnownUseEmpty" () uptr))

  (define %crest::SymbolOpInterface::replaceAllSymbolUses
    (crest-foreign-procedure "crest::SymbolOpInterface::replaceAllSymbolUses" () uptr))

  ) ;; end library (mlir IR SymbolInterfaces ffi)
