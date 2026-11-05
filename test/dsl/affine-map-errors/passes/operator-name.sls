#!r6rs
;; A pass library whose affine-map form is invalid; it must fail to compile.
(library (passes operator-name)
  (export run-pass)
  (import (except (rnrs) =) (crest))

  (define (run-pass module-op)
    (affine-map (d0 mod) () d0)))
