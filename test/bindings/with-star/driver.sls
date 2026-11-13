;; with* nests with- forms: each clause is in scope of the earlier ones, cleanups run in reverse order, also on
;; an error, and the body may start with internal definitions.
(import (rnrs)
        (crest support RAII)
        (crest support with)
        (mlir IR DialectRegistry)
        (mlir IR MLIRContext))

(define log '())
(define (note! x) (set! log (cons x log)))
(define (show label) (display label) (display ": ") (write (reverse log)) (newline) (set! log '()))

;; order of creation and of cleanup, and a later clause that uses an earlier variable
(with* ((with-raii a 'a (lambda (x) (note! (list 'free x))))
        (with-raii b (list a 'b) (lambda (x) (note! (list 'free x))))
        (with-raii c (list b 'c) (lambda (x) (note! (list 'free x)))))
  (note! (list 'body c)))
(show "order")

;; an error in the body still runs every cleanup, innermost first
(guard (e [#t (note! 'caught)])
  (with* ((with-raii a 1 (lambda (x) (note! (list 'free x))))
          (with-raii b 2 (lambda (x) (note! (list 'free x)))))
    (error 'test "boom")))
(show "error")

;; no clause: just the body, with internal definitions, and its value
(display (with* () (define x 40) (+ x 2)))
(newline)

;; internal definitions in the body of a non-empty with*
(display (with* ((with-raii a 1 (lambda (x) x))) (define y (+ a 1)) (* y 10)))
(newline)

;; the real macros of the project
(with* ((with-DialectRegistry registry ())
        (with-MLIRContext ctx (registry)))
  (display "context: ")
  (display (if (zero? ctx) "null" "made"))
  (newline))
