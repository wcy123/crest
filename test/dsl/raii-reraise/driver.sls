#!r6rs
;; with-raii frees its resource once, also when an error passes through a guard that has no clause for it.
;; R6RS guard re-raises such an error in the dynamic environment of the original raise: control goes back
;; into the body of with-raii and out again, and a destructor that is not protected runs twice.
(import (rnrs)
        (only (chezscheme) printf)
        (mlir support RAII))

(define frees 0)

(define (run)
  (guard (outer [#t 'caught])
    (guard (inner [(string? inner) 'not-for-us])
      (with-raii resource 'the-resource (lambda (r) (set! frees (+ frees 1)))
        (error 'driver "boom")))))

(run)
(printf "frees: ~a\n" frees)
