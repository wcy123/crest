;; scheme-mlir driver: with-raii frees its resource when the body returns, when it raises an error,
;; when it escapes through a continuation, and in reverse order when the macros are nested. It does
;; not free a resource whose constructor raised an error.
(import (rnrs)
        (crest support RAII))

(define log '())
(define (note x) (set! log (cons x log)))
(define (free-it resource) (note (list 'free resource)))

;; the body returns: the value of the last expression is the value of the macro
(note (with-raii a (begin (note 'make-1) 1) free-it
        (note 'body-1)
        'result))

;; the body raises an error
(guard (c [#t (note 'caught)])
  (with-raii b 2 free-it
    (error 'body "boom")))

;; the body escapes
(call/cc (lambda (k)
           (with-raii c 3 free-it
             (k 'out))))

;; nested: the inner resource is freed first
(with-raii d 4 free-it
  (with-raii e 5 free-it
    (note 'both)))

;; the constructor raises an error: nothing to free
(guard (c [#t (note 'caught-constructor)])
  (with-raii f (error 'constructor "boom") free-it
    (note 'not-reached)))

(for-each (lambda (x) (write x) (newline)) (reverse log))
