#!r6rs
;; Test: with-CrestObject returns the body's value on a normal return and lets an
;; error propagate to a guard outside the form.
(library (passes with-crestobject)
  (export run-pass)
  (import (rnrs)
          (only (mlir support CrestObject) with-CrestObject)
          (only (mlir support array-ref) make-array-ref))

  (define (run-pass module-op)
    ;; Normal return: the body's value is the value of the form.
    (display (with-CrestObject a (make-array-ref 0 0) 'normal))
    (newline)
    ;; Error caught by a guard outside the form.
    (display (guard (e [#t 'guard-caught])
               (with-CrestObject a (make-array-ref 0 0)
                 (error 'test "boom"))))
    (newline)))
