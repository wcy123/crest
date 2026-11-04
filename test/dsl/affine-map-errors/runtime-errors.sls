;; scheme-mlir program: the run-time errors of the affine-map operators. Each form is
;; well-formed, so it compiles, and raises when it runs.
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext)
        (crest))

(define (try thunk)
  (guard (e [#t (display (if (message-condition? e) (condition-message e) "other error"))
                (newline)])
    (thunk)
    (display "no error\n")))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (with-current-MLIRContext ctx
      ;; an operand that is neither an integer nor an AffineExpr
      (try (lambda () (affine-map (d0) () (+ d0 "x"))))
      ;; wrong operand count
      (try (lambda () (affine-map (d0) () (floordiv d0))))
      ;; integer-only arithmetic with a bad operand
      (try (lambda () (affine-map () () (+ 1 "x"))))
      ;; the rebound operators are local to the body: outside it + and mod are Scheme's
      (affine-map (d0) () (+ d0 1))
      (display (list (+ 1 2) (mod 7 3)))
      (newline))))
