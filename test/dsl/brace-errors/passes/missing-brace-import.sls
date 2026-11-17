#!chezscheme
;; A file that does not import { } from (crest) or (crest pattern-dsl keywords) gets an error that
;; says so, not an error about the next modifier.
(library (passes missing-brace-import)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (crest) define-pass-entry-point)
          (only (crest pattern-dsl rewrite) begin-mlir-code)
          (only (crest pattern-dsl keywords) = : ->))

  (define (%%build)
    (begin-mlir-code
        test.dst ()
        { test.a () }
        -> ()))

  (define-pass-entry-point (module-op) module-op)

  ) ;; end library
