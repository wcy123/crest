#!r6rs
(library (passes bad-unknown)
  (export badtest)
  (import (chezscheme)
          (crest dialect))

  (define-dialect badtest
    (define-op op
      :traits (terminatr))))
