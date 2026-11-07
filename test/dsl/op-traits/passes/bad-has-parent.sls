#!r6rs
(library (passes bad-has-parent)
  (export badtest)
  (import (chezscheme)
          (crest dialect))

  (define-dialect badtest
    (define-op op
      :traits ((has-parent)))))
