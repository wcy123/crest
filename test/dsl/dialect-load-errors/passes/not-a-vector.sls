#!r6rs
;; The name the dialect is loaded by is bound to something that is not the callbacks vector
;; define-dialect makes.
(library (passes not-a-vector)
  (export bad)
  (import (chezscheme))
  (define bad 42))
