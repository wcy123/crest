#!r6rs
(library (passes old-fold)
  (export od)
  (import (chezscheme)
          (crest dialect))

  (define-dialect od
    (define-op op
      (:fold (op) #f))))
