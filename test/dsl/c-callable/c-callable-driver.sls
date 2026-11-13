;; with-c-callable: a procedure becomes a C function for the body and is released after; the address of a
;; locked callable is used as it is and never unlocked; define-c-callable
;; keeps its callable locked.
(import (chezscheme)
        (crest callback))

(define (say . parts) (for-each display parts) (newline))
(define (yes/no b) (if b 'yes 'no))
(define (locked? entry) (locked-object? (foreign-callable-code-object entry)))
;; A callable has the C result type that its site writes: here int. (An error of its procedure is a
;; diagnostic: test/dsl/c-callable-results.)
(define (call-c entry argument) ((foreign-procedure entry (int) int) argument))
(define (call-c-int entry argument) (call-c entry argument))

;; A procedure: the C function calls it, it is locked in the body and unlocked after.
(let ([seen #f])
  (with-c-callable/lambda (entry (int) int (lambda (x) (+ x 1)))
    (set! seen entry)
    (say "answers: " (call-c entry 41))
    (say "locked in the body: " (yes/no (locked? entry))))
  (say "locked after the body: " (yes/no (locked? seen))))

;; An error in the body unlocks it too.
(let ([seen #f])
  (guard (c [#t (say "error caught")])
    (with-c-callable/lambda (entry (int) int (lambda (x) x))
      (set! seen entry)
      (error 'test "boom")))
  (say "locked after an error: " (yes/no (locked? seen))))

;; The address that define-c-callable answered: used as it is, still locked after.
(let ()
  (define-c-callable address ((x int)) int (+ x 100))
  (with-c-callable/code (entry address)
    (say "address answers: " (call-c entry 1)
         " same address: " (yes/no (= entry address))))
  (say "address still locked: " (yes/no (locked? address))))

;; The address of a callable that is not locked is an error, and the macro does not lock it.
(let* ([code (foreign-callable (lambda (x) x) (int) int)]
       [address (foreign-callable-entry-point code)])
  (guard (c [#t (say "unlocked address rejected")])
    (with-c-callable/code (entry address)
      (say "not reached")))
  (say "still not locked: " (yes/no (not (locked-object? code)))))

;; Not a procedure and not the address of a callable.
(guard (c [#t (say "a number rejected")])
  (with-c-callable/code (entry 42)
    (say "not reached")))

;; A static callable stays locked.
(let ()
  (define-c-callable entry ((x int)) int (- x 1))
  (say "static answers: " (call-c entry 43))
  (say "static locked: " (yes/no (locked? entry))))

;; Many runs of one procedure do not accumulate code objects: they are released.
(enable-object-counts #t)
(define (code-count)
  (collect 4 4)
  (apply + (map cadr (cdr (assq 'code (object-counts))))))
(with-c-callable/lambda (entry (int) int (lambda (x) x)) (call-c entry 1))
(define before (code-count))
(do ([i 0 (+ i 1)]) ((= i 300))
  (with-c-callable/lambda (entry (int) int (lambda (x) x)) (call-c entry i)))
(say "300 runs released: " (yes/no (< (- (code-count) before) 30)))
