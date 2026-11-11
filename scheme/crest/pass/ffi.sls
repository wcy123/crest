;; Bridges lib/Crest/SchemePass.cpp
(library (crest pass ffi)
  (export %crest::createSchemePass
          %crest::SchemePass::reportFailure)
  (import (chezscheme))

  ;; (string name) (uptr entry) → mlir::Pass* (the pass manager that it is added to owns it)
  ;; entry: the entry point of the foreign-callable of the body of the pass (see (crest pass))
  (define %crest::createSchemePass
    (foreign-procedure "crest::createSchemePass" (string uptr) uptr))

  ;; (string message) → void — the text of an error that the body of a pass raised, for the
  ;; diagnostic of its failure.
  (define %crest::SchemePass::reportFailure
    (foreign-procedure "crest::SchemePass::reportFailure" (string) void))

  ) ;; end library (crest pass ffi)
