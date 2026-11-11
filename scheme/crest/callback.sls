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
;;   (crest-make-static-c-callable (argument-type ...) result-type proc)   an address
;;   (crest-callback-pointer-list pointer count)                          a list of integers
;;   (crest-callback-condition-text condition)                            a string
;;   (crest-callback-entry-dispatcher entries)                            a procedure
;;
;; C++ never makes, owns, locks or releases a callback. A binding that needs one takes a plain C
;; function pointer; Scheme makes the foreign-callable (locked, because the garbage collector moves
;; code objects) and whoever calls the low-level function decides how long it lives. The types are
;; those of foreign-callable (uptr, int, void, ...).
;;
;;   crest-make-static-c-callable   locks it for good: a callback made once, at the library level, or
;;                                  one that a helper makes and cannot scope (about 400 bytes each).
;;   with-c-callable                locks it for the body and unlocks it after, also on an error. The
;;                                  value is a procedure, or a locked code object or the address of a
;;                                  locked callable that the caller made (reused, never unlocked here).
;;   with-c-callables               the same for several, nested in order.
;;
;; The conversion clauses (with-TypeConverter, with-ConversionTarget, with-RewritePatternSet) use
;; with-c-callables around their body.
;;
;; C++ gives a range (a TypeRange, say) as a pointer to an array and a count, not as a Scheme
;; list; crest-callback-pointer-list reads the count elements of 8 bytes at pointer.
;;
;;===----------------------------------------------------------------------===;;
(library (crest callback)
  (export crest-make-static-c-callable
          with-c-callable
          with-c-callables
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

  (define-syntax crest-make-static-c-callable
    (syntax-rules ()
      [(_ (argument-type ...) result-type proc)
       (let ([code (foreign-callable proc (argument-type ...) result-type)])
         (lock-object code)
         (foreign-callable-entry-point code))]))

  ;; (with-c-callable (name (argument-type ...) result-type value) body ...)
  ;;
  ;; Runs BODY with NAME bound to the address of a C function that calls what VALUE is:
  ;;
  ;;   a procedure: the macro makes the foreign-callable, locks it, and unlocks it when BODY ends, also
  ;;   when it ends by an error. Use it for a callback that C++ calls while BODY runs.
  ;;
  ;;   a callable that the caller made and keeps locked, to reuse it (making one costs about 200 ns):
  ;;   the code object of foreign-callable after lock-object, or an address that
  ;;   crest-make-static-c-callable answered. The macro uses it as it is and never unlocks it, because
  ;;   it is the caller's. An unlocked code object is an error: the garbage collector could move it,
  ;;   and C++ would call a stale address.
  ;;
  ;; The address is only valid inside BODY: if C++ keeps it after BODY ends, use
  ;; crest-make-static-c-callable.
  (define-syntax with-c-callable
    (syntax-rules ()
      [(_ (name (type ...) result value) body ...)
       (let* ([given value]
              [made? (procedure? given)]
              [code (cond
                     [made? (foreign-callable given (type ...) result)]
                     [(and (integer? given) (exact? given)) (foreign-callable-code-object given)]
                     [else given])])
         (when made? (lock-object code))
         (unless (locked-object? code)
           (assertion-violation 'with-c-callable
                                "the callable must be a procedure, or a locked code object, or the address of a locked callable"
                                given))
         (dynamic-wind
             (lambda () #f)
             (lambda () (let ([name (foreign-callable-entry-point code)]) body ...))
             (lambda () (when made? (unlock-object code)))))]))

  ;; (with-c-callables ((name (type ...) result value) ...) body ...): with-c-callable for each binding,
  ;; the first made first and released last. A binding may use the names of the ones before it.
  (define-syntax with-c-callables
    (syntax-rules ()
      [(_ () body ...) (let () body ...)]
      [(_ (binding rest ...) body ...)
       (with-c-callable binding (with-c-callables (rest ...) body ...))]))

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
  ;;   logical-result  an llvm::LogicalResult (one byte, 1 for success): Windows x64 answers it
  ;;                through the place that the caller gives, as for an object
  ;;   range        an ArrayRef or an OperandRange: the procedure answers (data . size)
  ;; The procedure gets only the arguments, not the Concept. Answers the entry point, as
  ;; crest-make-static-c-callable does.
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
             #`(crest-make-static-c-callable
                (uptr #,@types) #,result
                (lambda (concept #,@formals) (#,procedure #,@values)))]
            [(object)
             (if windows?
                 #`(crest-make-static-c-callable
                    (uptr uptr #,@types) uptr
                    (lambda (answer concept #,@formals)
                      (foreign-set! 'uptr answer 0 (#,procedure #,@values))
                      answer))
                 #`(crest-make-static-c-callable
                    (uptr #,@types) uptr
                    (lambda (concept #,@formals) (#,procedure #,@values))))]
            [(logical-result)
             (if windows?
                 #`(crest-make-static-c-callable
                    (uptr uptr #,@types) uptr
                    (lambda (answer concept #,@formals)
                      (foreign-set! 'unsigned-8 answer 0 (#,procedure #,@values))
                      answer))
                 #`(crest-make-static-c-callable
                    (uptr #,@types) unsigned-8
                    (lambda (concept #,@formals) (#,procedure #,@values))))]
            [(range)
             #`(crest-make-static-c-callable
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
