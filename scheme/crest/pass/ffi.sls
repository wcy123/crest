;; Bridges lib/Crest/SchemePass.cpp
(library (crest pass ffi)
  (export %crest::createSchemePass)
  (import (chezscheme))

  ;; (string name) (scheme-object procedure) → CrestBox<unique_ptr<mlir::Pass>>*
  (define %crest::createSchemePass
    (foreign-procedure "crest::createSchemePass" (string scheme-object) uptr))

  ) ;; end library (crest pass ffi)
