;; with-c-callable: a procedure becomes a C function for the body and is released after; a code object
;; that the user made and locked is used as it is and never unlocked; crest-make-static-c-callable
;; keeps its callable locked.
(import (chezscheme)
        (crest callback))

(define (say . parts) (for-each display parts) (newline))
(define (yes/no b) (if b 'yes 'no))
(define (locked? entry) (locked-object? (foreign-callable-code-object entry)))
;; A callable that crest-make-static-c-callable and with-c-callable make answers a Scheme object: what
;; the procedure answered, or (who . why) if it raised an error. A code object that the user made
;; answers its own C type.
(define (call-c entry argument) ((foreign-procedure entry (int) scheme-object) argument))
(define (call-c-int entry argument) ((foreign-procedure entry (int) int) argument))

;; A procedure: the C function calls it, it is locked in the body and unlocked after.
(let ([seen #f])
  (with-c-callable (entry (int) scheme-object (lambda (x) (+ x 1)))
    (set! seen entry)
    (say "answers: " (call-c entry 41))
    (say "locked in the body: " (yes/no (locked? entry))))
  (say "locked after the body: " (yes/no (locked? seen))))

;; An error that the procedure raises does not leave the C function: it answers (who . why).
(with-c-callable (entry (int) scheme-object (lambda (x) (error 'boom "bad")))
  (say "error answered: " (call-c entry 7)))

;; An error in the body unlocks it too.
(let ([seen #f])
  (guard (c [#t (say "error caught")])
    (with-c-callable (entry (int) scheme-object (lambda (x) x))
      (set! seen entry)
      (error 'test "boom")))
  (say "locked after an error: " (yes/no (locked? seen))))

;; A code object that the user made and locked: used as it is, still locked after.
(let* ([code (foreign-callable (lambda (x) (* x 2)) (int) int)])
  (lock-object code)
  (with-c-callable (entry (int) scheme-object code)
    (say "reused answers: " (call-c-int entry 21)))
  (say "reused still locked: " (yes/no (locked-object? code)))
  (unlock-object code))

;; The address that crest-make-static-c-callable answered: used as it is, still locked after.
(let ([address (crest-make-static-c-callable (int) scheme-object (lambda (x) (+ x 100)))])
  (with-c-callable (entry (int) scheme-object address)
    (say "address answers: " (call-c entry 1)
         " same address: " (yes/no (= entry address))))
  (say "address still locked: " (yes/no (locked? address))))

;; A code object that is not locked is an error, and it is not locked by the macro.
(let* ([code (foreign-callable (lambda (x) x) (int) int)])
  (guard (c [#t (say "unlocked code rejected")])
    (with-c-callable (entry (int) scheme-object code)
      (say "not reached")))
  (say "still not locked: " (yes/no (not (locked-object? code)))))

;; Not a procedure and not a code object.
(guard (c [#t (say "a number rejected")])
  (with-c-callable (entry (int) scheme-object 42)
    (say "not reached")))

;; A static callable stays locked.
(let ([entry (crest-make-static-c-callable (int) scheme-object (lambda (x) (- x 1)))])
  (say "static answers: " (call-c entry 43))
  (say "static locked: " (yes/no (locked? entry))))

;; Many runs of one procedure do not accumulate code objects: they are released.
(enable-object-counts #t)
(define (code-count)
  (collect 4 4)
  (apply + (map cadr (cdr (assq 'code (object-counts))))))
(with-c-callable (entry (int) scheme-object (lambda (x) x)) (call-c entry 1))
(define before (code-count))
(do ([i 0 (+ i 1)]) ((= i 300))
  (with-c-callable (entry (int) scheme-object (lambda (x) x)) (call-c entry i)))
(say "300 runs released: " (yes/no (< (- (code-count) before) 30)))
