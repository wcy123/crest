#!r6rs
(library (passes bad-repeated)
  (export badtest)
  (import (chezscheme)
          (crest dialect))

  (define-dialect badtest
    (define-op op
      :traits (terminator terminator))))
