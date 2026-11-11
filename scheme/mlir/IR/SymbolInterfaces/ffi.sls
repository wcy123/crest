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
  (import (chezscheme))

  ;; () -> uptr: the TypeID of the interface, as the address that the TypeID wraps.
  (define %mlir::SymbolOpInterface::getInterfaceID
    (foreign-procedure "mlir::SymbolOpInterface::getInterfaceID" () uptr))

  ;; The methods of the interface on an op, through the Concept of the op.
  (define %mlir::SymbolOpInterface::getNameAttr
    (foreign-procedure "mlir::SymbolOpInterface::getNameAttr" (uptr) uptr))

  (define %mlir::SymbolOpInterface::setName
    (foreign-procedure "mlir::SymbolOpInterface::setName" (uptr uptr) void))

  ;; The visibility is a number: 0 public, 1 private, 2 nested.
  (define %mlir::SymbolOpInterface::getVisibility
    (foreign-procedure "mlir::SymbolOpInterface::getVisibility" (uptr) int))

  (define %mlir::SymbolOpInterface::isNested
    (foreign-procedure "mlir::SymbolOpInterface::isNested" (uptr) int))

  (define %mlir::SymbolOpInterface::isPrivate
    (foreign-procedure "mlir::SymbolOpInterface::isPrivate" (uptr) int))

  (define %mlir::SymbolOpInterface::isPublic
    (foreign-procedure "mlir::SymbolOpInterface::isPublic" (uptr) int))

  (define %mlir::SymbolOpInterface::setVisibility
    (foreign-procedure "mlir::SymbolOpInterface::setVisibility" (uptr int) void))

  (define %mlir::SymbolOpInterface::setNested
    (foreign-procedure "mlir::SymbolOpInterface::setNested" (uptr) void))

  (define %mlir::SymbolOpInterface::setPrivate
    (foreign-procedure "mlir::SymbolOpInterface::setPrivate" (uptr) void))

  (define %mlir::SymbolOpInterface::setPublic
    (foreign-procedure "mlir::SymbolOpInterface::setPublic" (uptr) void))

  (define %mlir::SymbolOpInterface::symbolKnownUseEmpty
    (foreign-procedure "mlir::SymbolOpInterface::symbolKnownUseEmpty" (uptr uptr) int))

  (define %mlir::SymbolOpInterface::replaceAllSymbolUses
    (foreign-procedure "mlir::SymbolOpInterface::replaceAllSymbolUses" (uptr uptr uptr) int))

  (define %mlir::SymbolOpInterface::isOptionalSymbol
    (foreign-procedure "mlir::SymbolOpInterface::isOptionalSymbol" (uptr) int))

  (define %mlir::SymbolOpInterface::canDiscardOnUseEmpty
    (foreign-procedure "mlir::SymbolOpInterface::canDiscardOnUseEmpty" (uptr) int))

  (define %mlir::SymbolOpInterface::isDeclaration
    (foreign-procedure "mlir::SymbolOpInterface::isDeclaration" (uptr) int))

  ;; () -> uptr: the address of a C function that CREST ships for a slot that Scheme cannot write
  ;; (lib/Bindings/IR/SymbolInterfaces.cpp): what SymbolTable answers.
  (define %crest::SymbolOpInterface::getSymbolUses
    (foreign-procedure "crest::SymbolOpInterface::getSymbolUses" () uptr))

  (define %crest::SymbolOpInterface::symbolKnownUseEmpty
    (foreign-procedure "crest::SymbolOpInterface::symbolKnownUseEmpty" () uptr))

  (define %crest::SymbolOpInterface::replaceAllSymbolUses
    (foreign-procedure "crest::SymbolOpInterface::replaceAllSymbolUses" () uptr))

  ) ;; end library (mlir IR SymbolInterfaces ffi)
