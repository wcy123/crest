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
;; C++ is to call later gets a C function of its own: a foreign-callable, which is locked for the
;; life of the process, and whose address is what C++ stores. The types are those of
;; foreign-callable (uptr, int, void, ...). The callable is never freed, so use it for what is made
;; once per op or per dialect, not for a closure made per run.
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
