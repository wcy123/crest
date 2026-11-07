#!r6rs
(library (passes bad-not-a-list)
  (export badtest)
  (import (chezscheme)
          (crest dialect))

  (define-dialect badtest
    (define-op op
      :traits terminator)))
