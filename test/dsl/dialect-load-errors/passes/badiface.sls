#!r6rs
;; A Scheme dialect whose dialect-level :interfaces names an interface that a dialect cannot have
;; (only mlir::DialectInlinerInterface is one), so C++ has no way to install it.
(library (passes badiface)
  (export badiface)
  (import (chezscheme)
          (crest dialect)
          (only (mlir IR SymbolInterfaces) mlir::SymbolOpInterface))

  (define-dialect badiface
    (:interfaces ((mlir::SymbolOpInterface)))
    (define-op thing
      :summary "an op")))
