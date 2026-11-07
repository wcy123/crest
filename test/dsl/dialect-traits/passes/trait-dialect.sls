#!r6rs
;; A Scheme dialect whose ops declare traits. traittest.ret is a terminator and
;; traittest.plain is not; both have the generic assembly format.
(library (passes trait-dialect)
  (export traittest)
  (import (chezscheme)
          (crest dialect))

  (define-dialect traittest
    (define-op wrap
      :summary "holds one region")
    (define-op plain
      :summary "an op without traits")
    (define-op ret
      :summary "a terminator"
      :traits (terminator))))
