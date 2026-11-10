#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest callback) — C function pointers made from Scheme procedures.
;;
;;   (crest-callback-entry-point (argument-type ...) result-type proc)   an address
;;   (crest-callback-pointer-list pointer count)                          a list of integers
;;   (crest-callback-condition-text condition)                            a string
;;   (crest-callback-entry-dispatcher entries)                            a procedure
;;
;; C++ cannot keep a Scheme procedure without telling the garbage collector, so a procedure that
;; C++ is to call later gets a C function of its own: a foreign-callable, which is locked, and
;; whose address is what C++ stores. The types are those of foreign-callable (uptr, int, void, ...).
;; The lock is taken once, here, and who releases it depends on how long the callable is used:
;;
;;   made once per library (an op's clause, a dialect's callback, the body of a pass): define it at
;;   the library level; C++ keeps the address as a plain function pointer and never releases it.
;;
;;   made for a run (a closure that the user passes to a pattern, a type converter, a walk): not made
;;   here. Scheme gives C++ the procedure, adapted to the C types, and C++ makes the callable with
;;   crest::ForeignCallable<R(Args...)>::fromProcedure (lib/Bindings/Support/ForeignCallable.h), which
;;   deduces the prototype from the C++ type and releases the lock when whatever calls the function
;;   is destroyed.
;;
;; C++ gives a range (a TypeRange, say) as a pointer to an array and a count, not as a Scheme
;; list; crest-callback-pointer-list reads the count elements of 8 bytes at pointer.
;;
;;===----------------------------------------------------------------------===;;
(library (crest callback)
  (export crest-callback-entry-point
          crest-callback-pointer-list
          crest-callback-condition-text
          crest-callback-entry-dispatcher)
  (import (chezscheme))

  (define-syntax crest-callback-entry-point
    (syntax-rules ()
      [(_ (argument-type ...) result-type proc)
       (let ([code (foreign-callable proc (argument-type ...) result-type)])
         (lock-object code)
         (foreign-callable-entry-point code))]))

  (define (crest-callback-pointer-list pointer count)
    (map (lambda (i) (foreign-ref 'uptr pointer (* i 8))) (iota count)))

  ;; The text of the condition of an error that a callable catches, which goes to C++ so that the
  ;; diagnostic of the failure shows it.
  (define (crest-callback-condition-text condition)
    (call-with-string-output-port
     (lambda (port) (display-condition condition port))))

  ;; What the macro of an interface hands to C++ (the :interfaces clause of define-op): from a method
  ;; name to the entry point of its callable, 0 for a method that the op has no clause for. C++ asks
  ;; for each method of the interface while it registers the op (lib/Crest/Interface.h). `entries`
  ;; is an alist of (method . entry point).
  (define (crest-callback-entry-dispatcher entries)
    (lambda (method)
      (cond
       [(assq method entries) => cdr]
       [else 0])))

  ) ;; end library (crest callback)
