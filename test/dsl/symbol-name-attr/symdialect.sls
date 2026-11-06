#!r6rs
;; A Scheme dialect whose op reads a symbol name into an attribute called "target", not "callee":
;; mlir::OpAsmParser::parseSymbolName takes the attribute name, as the C++ function does.
(library (symdialect)
  (export toy)
  (import (chezscheme)
          (crest dialect)
          (mlir IR OpImplementation))

  (define-dialect toy
    (define-op ref
      :summary "op that names a symbol"
      (:parse (parser state)
        (string<? "" (mlir::OpAsmParser::parseSymbolName parser state "target"))))))
