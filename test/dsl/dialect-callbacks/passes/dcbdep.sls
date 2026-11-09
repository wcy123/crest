#!r6rs
;; A dialect that dcb depends on: it says when it is initialized.
(library (passes dcbdep)
  (export dcbdep)
  (import (rnrs)
          (crest dialect))

  (define-dialect dcbdep
    (:initialize (dialect)
      (let ([port (current-output-port)])
        (display "dcbdep initialize\n" port)
        (flush-output-port port)))
    (define-op marker
      :summary "an op, so that the dialect has one")))
