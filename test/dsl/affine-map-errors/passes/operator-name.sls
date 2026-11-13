#!r6rs
;; A pass library whose affine-map form is invalid; it must fail to compile.
(library (passes operator-name)
  (export pass-entry-point)
  (import (except (rnrs) =) (crest))

  (define-pass-entry-point (module-op)
    (affine-map (d0 mod) () d0)))
