#!r6rs
;; Test: with-CrestObject returns the body's value on a normal return and lets an
;; error propagate to a guard outside the form.
(library (passes with-crestobject)
  (export run-pass)
  (import (rnrs)
          (only (mlir support CrestObject) with-CrestObject)
          (only (mlir IR DialectRegistry ffi) %mlir::DialectRegistry::new))

  (define (run-pass module-op)
    ;; Normal return: the body's value is the value of the form.
    (display (with-CrestObject a (%mlir::DialectRegistry::new) 'normal))
    (newline)
    ;; Error caught by a guard outside the form.
    (display (guard (e [#t 'guard-caught])
               (with-CrestObject a (%mlir::DialectRegistry::new)
                 (error 'test "boom"))))
    (newline)))
