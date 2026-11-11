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
          crest-callback-entry-dispatcher
          crest-slot-callable)
  (import (chezscheme))

  ;; A pair of words that C++ passes or returns by value: an llvm::ArrayRef, a TypeRange, an
  ;; OperandRange (a pointer and a count). Chez makes a foreign-callable that takes or answers such a
  ;; struct follow the rules of the platform: two registers on Linux, a pointer to a copy on Windows.
  (define-ftype %%SlotRange (struct [data uptr] [size uptr]))

  ;; The elements of a range C++ gave as two words (crest::TypeRange::toList): a TypeRange is not an
  ;; array, its first word has a tag.
  (define %%type-range->list
    (foreign-procedure "crest::TypeRange::toList" (uptr uptr) scheme-object))

  ;; Windows x64 (a6nt, ta6nt): a class with a constructor is returned through a pointer even when
  ;; it is one word (Type, StringAttr, a PointerUnion), where it is passed in a register.
  (define (%%windows?)
    (let* ([name (symbol->string (machine-type))]
           [n (string-length name)])
      (and (>= n 2) (string=? (substring name (- n 2) n) "nt"))))

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

  ;; The callable of a slot of a Concept, which MLIR calls as a C function: a pointer to the Concept
  ;; first (ignored), then the arguments of the method. The kinds are the C++ types of the slot, and
  ;; the macro writes the prototype of the platform, so the procedure sees numbers and lists:
  ;;
  ;;   (crest-slot-callable (argument-kind ...) result-kind procedure)
  ;;
  ;; argument kinds: uptr, int, unsigned-8 (a bool), unsigned-32, and
  ;;   object       a class of one pointer (Type, TypeAttr, StringAttr, ...), by value: the procedure gets
  ;;                the pointer, on every platform (an argument of one word is passed in a register)
  ;;   type-range   a TypeRange by value: the procedure gets the list of the types
  ;; result kinds: void, uptr, int, unsigned-8, unsigned-32, and
  ;;   object       the procedure answers the pointer; Windows x64 answers a class that has a
  ;;                constructor through the place that the caller gives (a pointer before the Concept)
  ;;   range        an ArrayRef or an OperandRange: the procedure answers (data . size)
  ;; The procedure gets only the arguments, not the Concept. Answers the entry point, as
  ;; crest-callback-entry-point does.
  (define-syntax crest-slot-callable
    (lambda (stx)
      (define (argument-info kind windows?)
        ;; a pair: the C type, and a procedure from the formal to the expression
        (case (syntax->datum kind)
          [(uptr int unsigned-8 unsigned-32) (cons kind (lambda (formal) formal))]
          [(object) (cons #'uptr (lambda (formal) formal))]
          [(type-range)
           (cons #'(& %%SlotRange)
                 (lambda (formal)
                   #`(%%type-range->list (ftype-ref %%SlotRange (data) #,formal)
                                         (ftype-ref %%SlotRange (size) #,formal))))]
          [else (syntax-violation 'crest-slot-callable "unknown kind of argument" stx kind)]))
      (define (callable windows? kinds result procedure)
        (let* ([formals (generate-temporaries kinds)]
               [infos (map (lambda (kind) (argument-info kind windows?)) kinds)]
               [types (map car infos)]
               [values (map (lambda (info formal) ((cdr info) formal)) infos formals)])
          (case (syntax->datum result)
            [(void uptr int unsigned-8 unsigned-32)
             #`(crest-callback-entry-point
                (uptr #,@types) #,result
                (lambda (concept #,@formals) (#,procedure #,@values)))]
            [(object)
             (if windows?
                 #`(crest-callback-entry-point
                    (uptr uptr #,@types) uptr
                    (lambda (answer concept #,@formals)
                      (foreign-set! 'uptr answer 0 (#,procedure #,@values))
                      answer))
                 #`(crest-callback-entry-point
                    (uptr #,@types) uptr
                    (lambda (concept #,@formals) (#,procedure #,@values))))]
            [(range)
             #`(crest-callback-entry-point
                (uptr #,@types) (& %%SlotRange)
                (lambda (answer concept #,@formals)
                  (let ([pair (#,procedure #,@values)])
                    (ftype-set! %%SlotRange (data) answer (car pair))
                    (ftype-set! %%SlotRange (size) answer (cdr pair)))))]
            [else (syntax-violation 'crest-slot-callable "unknown kind of result" stx result)])))
      (syntax-case stx ()
        [(_ (kind ...) result procedure)
         #`(let ([p procedure])
             (if (%%windows?)
                 #,(callable #t #'(kind ...) #'result #'p)
                 #,(callable #f #'(kind ...) #'result #'p)))])))

  ) ;; end library (crest callback)
