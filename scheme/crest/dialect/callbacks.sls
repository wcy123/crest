#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest dialect callbacks) — the callbacks of a Scheme dialect as C functions.
;;
;;   (crest-dialect-callback-entries initialize get-dependent-dialects parse-attribute
;;     print-attribute parse-type print-type materialize-constant get-canonicalization-patterns
;;     verify-op-attr verify-region-arg-attr verify-region-result-attr interfaces)  a vector
;;   (crest-op-callback-entries op-name verify verify-regions parse print fold
;;     get-canonicalization-patterns populate-default-attrs traits)            a vector
;;   (crest-type-callback-entries verify parse print)                          a vector
;;
;; Each argument is the expression the dialect wrote for that clause of define-dialect, or #f (these
;; are macros, so that an error of a procedure is reported at the Scheme source of its clause). The
;; answer is a vector: for each slot, in the same order, the entry point of a foreign-callable that
;; calls the procedure (see (crest callback)), with the C result type of the hook, or 0 for #f. C++ keeps the addresses
;; (lib/Crest/Dialect.cpp for the dialect, Op.cpp for an op, Type.cpp for a type). define-dialect
;; calls each of these once, when the library of the dialect is loaded, so a context that loads the
;; dialect makes no callable of its own. The vector of the dialect is bound to the dialect's name;
;; those of an op and of a type are given to crest::register-dynamic-op! and -type! when the
;; context initializes the dialect.
;;
;; The procedures keep the arguments they always had. What changes is how an answer is told to C:
;;   - a pointer that is #f is 0 (a parse that failed, no constant);
;;   - get-dependent-dialects answers a list of dialect names (strings);
;;   - a verifier says yes with any value but #f. An error that a procedure here raises (a verifier, a
;;     parser, a folder, ...) does not leave the callable: it is a diagnostic at the Scheme source of the
;;     clause, and the callable answers 0. A hook that answers nothing (a printer, initialize) ends
;;     the process with the text of the error;
;;   - a folder answers #f (no fold) or a list of (fold-value v) and (fold-attribute a), the empty
;;     list for an op that it changed in place; its operand attributes are a list of one entry per
;;     operand, the constant attribute or #f;
;;   - the verify of a type answers #t, #f or a message (a string); its parse a list of attributes
;;     or #f; its print gets the list of the parameters.
;;
;;===----------------------------------------------------------------------===;;
(library (crest dialect callbacks)
  (export crest-dialect-callback-entries
          crest-op-callback-entries
          crest-type-callback-entries)
  (import (chezscheme)
          (crest callback)
          (crest dialect ffi))

  ;; (%%entry (argument-type ...) result-type clause adapter): the entry point of the callable for one
  ;; slot, or 0 when the dialect did not write the clause (it is #f). CLAUSE is the expression of the user;
  ;; ADAPTER is applied to its value and answers the procedure that the callable calls. An error of the
  ;; procedure is reported at the Scheme position of CLAUSE, which is in the form that the callable is made from.
  (define-syntax %%entry
    (lambda (stx)
      (syntax-case stx ()
        [(_ (type ...) result clause adapter)
         (if (syntax->datum #'clause)
             #'(crest-make-static-c-callable (type ...) result (adapter clause))
             #'0)])))

  ;; The folder of an op as C wants it. Its operands come as a pointer and a count (0 for no
  ;; constant); its answer is pushed into `folded` one result at a time. 0 is no fold; 1 is a fold,
  ;; with no result at all when the op was changed in place.
  (define (%%fold-adapter fold)
    (lambda (op attributes count folded)
      (let ([result (fold op (map (lambda (attribute) (if (eqv? attribute 0) #f attribute))
                                  (crest-callback-pointer-list attributes count)))])
        (let push ([results result])
          (cond
           [(not results) 0]
           [(not (pair? results)) 1]
           [(and (pair? (car results)) (eq? (caar results) 'value))
            (%crest::Fold::addValue folded (cdar results))
            (push (cdr results))]
           [(and (pair? (car results)) (eq? (caar results) 'attribute))
            (%crest::Fold::addAttribute folded (cdar results))
            (push (cdr results))]
           [else
            (error #f "fold callback: a result must be made by fold-value or fold-attribute")])))))

  ;; The entry points of the callbacks of a dialect, in the order of the slots of CrestDialect::Callbacks.
  ;; Each argument is the expression of the clause, or #f. The C result type of each is that of
  ;; lib/Crest/Dialect.h: void, a pointer (0 for a parse that failed) or 1/0 for a verdict.
  (define-syntax crest-dialect-callback-entries
    (syntax-rules ()
      [(_ initialize get-dependent-dialects parse-attribute print-attribute parse-type print-type
          materialize-constant get-canonicalization-patterns verify-op-attr
          verify-region-arg-attr verify-region-result-attr interfaces)
       (vector
        (%%entry (uptr) void initialize values)
        (%%entry (uptr) void get-dependent-dialects
                 (lambda (p)
                   (lambda (dialect)
                     (for-each (lambda (name) (%crest::CrestDialect::loadDependentDialect dialect name))
                               (p)))))
        (%%entry (uptr uptr) uptr parse-attribute
                 (lambda (p) (lambda (parser type) (or (p parser type) 0))))
        (%%entry (uptr uptr) void print-attribute values)
        (%%entry (uptr) uptr parse-type (lambda (p) (lambda (parser) (or (p parser) 0))))
        (%%entry (uptr uptr) void print-type values)
        (%%entry (uptr uptr uptr uptr) uptr materialize-constant
                 (lambda (p)
                   (lambda (builder value type loc) (or (p builder value type loc) 0))))
        (%%entry (uptr) void get-canonicalization-patterns values)
        (%%entry (uptr uptr) int verify-op-attr
                 (lambda (p) (lambda (op attr) (if (p op attr) 1 0))))
        (%%entry (uptr unsigned-32 unsigned-32 uptr) int verify-region-arg-attr
                 (lambda (p)
                   (lambda (op region-index arg-index attr)
                     (if (p op region-index arg-index attr) 1 0))))
        (%%entry (uptr unsigned-32 unsigned-32 uptr) int verify-region-result-attr
                 (lambda (p)
                   (lambda (op region-index result-index attr)
                     (if (p op region-index result-index attr) 1 0))))
        ;; Slot 11, data: the list of (TypeID . dispatcher) pairs of the dialect's :interfaces entries.
        interfaces)]))

  ;; The slots of an op: verify, verify-regions, parse, print, fold, get-canonicalization-patterns,
  ;; populate-default-attrs, and the list of its traits, which is data. `op-name` is the full name
  ;; of the op: print gets it as it always has.
  (define-syntax crest-op-callback-entries
    (syntax-rules ()
      [(_ op-name verify verify-regions parse print fold get-canonicalization-patterns
          populate-default-attrs traits)
       (vector
        (%%entry (uptr) int verify (lambda (p) (lambda (op) (if (p op) 1 0))))
        (%%entry (uptr) int verify-regions (lambda (p) (lambda (op) (if (p op) 1 0))))
        (%%entry (uptr uptr) int parse
                 (lambda (p) (lambda (parser state) (if (p parser state) 1 0))))
        (%%entry (uptr uptr) void print
                 (lambda (p) (lambda (op printer) (p op printer op-name))))
        (%%entry (uptr uptr uptr uptr) int fold %%fold-adapter)
        (%%entry (uptr) void get-canonicalization-patterns values)
        (%%entry (uptr uptr) void populate-default-attrs values)
        traits)]))

  ;; The slots of a type: verify, parse, print. An error that a procedure raises is a diagnostic at its
  ;; Scheme source, and the callable answers 0 (print has no result: the process ends).
  ;;   verify  (params) → #t | #f | a message. C: 1, 0 (MLIR's message) or 2 (the message is in sink)
  ;;   parse   (parser) → a list of attributes | #f. C: 1 (the parameters are in sink), 0
  ;;   print   (printer params). C gets the parameters as a pointer and a count
  (define-syntax crest-type-callback-entries
    (syntax-rules ()
      [(_ verify parse print)
       (vector
        (%%entry (uptr uptr uptr) int verify
                 (lambda (p)
                   (lambda (params count sink)
                     (let ([answer (p (crest-callback-pointer-list params count))])
                       (cond
                        [(string? answer) (%crest::DynamicType::setMessage sink answer) 2]
                        [answer 1]
                        [else 0])))))
        (%%entry (uptr uptr) int parse
                 (lambda (p)
                   (lambda (parser sink)
                     (let ([parsed (p parser)])
                       (cond
                        [parsed
                         (for-each (lambda (attribute) (%crest::DynamicType::addParam sink attribute))
                                   parsed)
                         1]
                        [else 0])))))
        (%%entry (uptr uptr uptr) void print
                 (lambda (p)
                   (lambda (printer params count)
                     (p printer (crest-callback-pointer-list params count))))))]))

  ) ;; end library (crest dialect callbacks)
