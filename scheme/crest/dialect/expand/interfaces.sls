;; The callbacks vector of a dialect: slot 0 is %%<dialect>:initialize, which registers the ops of
;; the dialect (an op gets its interfaces from its :interfaces entries, see (crest dialect expand)).
(library (crest dialect expand interfaces)
  (export dialect-cbs-with-interfaces)
  (import (chezscheme)
          (crest dialect ast)
          (crest dialect expand utils))

  ;; Build the 11-slot dialect callbacks vector (slots 0-10).
  ;; Build the 11-slot dialect callbacks vector (slots 0-10).
  ;; Slot 0 → %%<dialect>:initialize.
  (define (dialect-cbs-with-interfaces ctx dialect-cbs ops)
    (let ([v (list->vector (map (lambda (i) (or (vector-ref dialect-cbs i) #'#f))
                                '(0 1 2 3 4 5 6 7 8 9 10)))])
      (vector-set! v 0 (%%id ctx "%%" ctx ":initialize"))
      (vector->list v)))

  ) ;; end library (crest dialect expand interfaces)
