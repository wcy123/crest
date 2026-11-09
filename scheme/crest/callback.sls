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
;;
;; C++ cannot keep a Scheme procedure without telling the garbage collector, so a procedure that
;; C++ is to call later gets a C function of its own: a foreign-callable, which is locked, and
;; whose address is what C++ stores. The types are those of foreign-callable (uptr, int, void, ...).
;; The lock is taken once, here, and who releases it depends on how long the callable is used:
;;
;;   made once per library (an op's clause, a dialect's callback, the body of a pass): define it at
;;   the library level; C++ keeps the address as a plain function pointer and never releases it.
;;
;;   made for a run (a closure that the user passes to a pattern, a type converter, a walk): C++
;;   gives the address to a crest::ForeignCallable (lib/Bindings/Support/ForeignCallable.h), which
;;   takes over this lock and releases it when whatever calls the function is destroyed.
;;
;; C++ gives a range (a TypeRange, say) as a pointer to an array and a count, not as a Scheme
;; list; crest-callback-pointer-list reads the count elements of 8 bytes at pointer.
;;
;;===----------------------------------------------------------------------===;;
(library (crest callback)
  (export crest-callback-entry-point
          crest-callback-pointer-list)
  (import (chezscheme))

  (define-syntax crest-callback-entry-point
    (syntax-rules ()
      [(_ (argument-type ...) result-type proc)
       (let ([code (foreign-callable proc (argument-type ...) result-type)])
         (lock-object code)
         (foreign-callable-entry-point code))]))

  (define (crest-callback-pointer-list pointer count)
    (map (lambda (i) (foreign-ref 'uptr pointer (* i 8))) (iota count)))

  ) ;; end library (crest callback)
