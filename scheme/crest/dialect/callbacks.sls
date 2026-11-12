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
;; Each argument is the procedure the dialect wrote for that clause of define-dialect, or #f. The
;; answer is a vector: for each slot, in the same order, the entry point of a foreign-callable that
;; calls the procedure (see (crest callback)), or 0 for #f. C++ keeps the addresses
;; (lib/Crest/Dialect.cpp for the dialect, Op.cpp for an op, Type.cpp for a type). define-dialect
;; calls each of these once, when the library of the dialect is loaded, so a context that loads the
;; dialect makes no callable of its own. The vector of the dialect is bound to the dialect's name;
;; those of an op and of a type are given to crest::register-dynamic-op! and -type! when the
;; context initializes the dialect.
;;
;; The procedures keep the arguments they always had. What changes is how an answer is told to C:
;;   - a pointer that is #f is 0 (a parse that failed, no constant);
;;   - get-dependent-dialects answers a list of dialect names (strings);
;;   - a verifier says yes with any value but #f. An error that it raises does not leave the
;;     callable: the callable answers it to C++ as (who . why), which reports it as the diagnostic of
;;     the failure. So it does for every procedure here (a parser, a folder, a printer, ...);
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

  ;; The folder of an op as C wants it. Its operands come as a pointer and a count (0 for no
  ;; constant); its answer is pushed into `folded` one result at a time. 0 is no fold; 1 is a fold,
  ;; with no result at all when the op was changed in place.
  (define (%%fold-entry-point fold)
    (crest-make-static-c-callable
     (uptr uptr uptr uptr) scheme-object
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
             (error #f "fold callback: a result must be made by fold-value or fold-attribute")]))))))

  (define (crest-dialect-callback-entries initialize get-dependent-dialects parse-attribute
                                          print-attribute parse-type print-type
                                          materialize-constant get-canonicalization-patterns
                                          verify-op-attr verify-region-arg-attr
                                          verify-region-result-attr interfaces)
    (vector
     (if initialize
         (crest-make-static-c-callable (uptr) scheme-object initialize)
         0)
     (if get-dependent-dialects
         (crest-make-static-c-callable
          (uptr) scheme-object
          (lambda (dialect)
            (for-each (lambda (name) (%crest::CrestDialect::loadDependentDialect dialect name))
                      (get-dependent-dialects))))
         0)
     (if parse-attribute
         (crest-make-static-c-callable
          (uptr uptr) scheme-object
          (lambda (parser type) (or (parse-attribute parser type) 0)))
         0)
     (if print-attribute
         (crest-make-static-c-callable (uptr uptr) scheme-object print-attribute)
         0)
     (if parse-type
         (crest-make-static-c-callable
          (uptr) scheme-object
          (lambda (parser) (or (parse-type parser) 0)))
         0)
     (if print-type
         (crest-make-static-c-callable (uptr uptr) scheme-object print-type)
         0)
     (if materialize-constant
         (crest-make-static-c-callable
          (uptr uptr uptr uptr) scheme-object
          (lambda (builder value type loc) (or (materialize-constant builder value type loc) 0)))
         0)
     (if get-canonicalization-patterns
         (crest-make-static-c-callable (uptr) scheme-object get-canonicalization-patterns)
         0)
     (if verify-op-attr
         (crest-make-static-c-callable
          (uptr uptr) scheme-object
          (lambda (op attr) (if (verify-op-attr op attr) 1 0)))
         0)
     (if verify-region-arg-attr
         (crest-make-static-c-callable
          (uptr unsigned-32 unsigned-32 uptr) scheme-object
          (lambda (op region-index arg-index attr)
            (if (verify-region-arg-attr op region-index arg-index attr) 1 0)))
         0)
     (if verify-region-result-attr
         (crest-make-static-c-callable
          (uptr unsigned-32 unsigned-32 uptr) scheme-object
          (lambda (op region-index result-index attr)
            (if (verify-region-result-attr op region-index result-index attr) 1 0)))
         0)
     ;; Slot 11, data: the list of (TypeID . dispatcher) pairs of the dialect's :interfaces entries.
     interfaces))

  ;; The slots of an op: verify, verify-regions, parse, print, fold, get-canonicalization-patterns,
  ;; populate-default-attrs, and the list of its traits, which is data. `op-name` is the full name
  ;; of the op: print gets it as it always has.
  (define (crest-op-callback-entries op-name verify verify-regions parse print fold
                                     get-canonicalization-patterns populate-default-attrs traits)
    (vector
     (if verify
         (crest-make-static-c-callable (uptr) scheme-object (lambda (op) (if (verify op) 1 0)))
         0)
     (if verify-regions
         (crest-make-static-c-callable
          (uptr) scheme-object
          (lambda (op) (if (verify-regions op) 1 0)))
         0)
     (if parse
         (crest-make-static-c-callable
          (uptr uptr) scheme-object
          (lambda (parser state) (if (parse parser state) 1 0)))
         0)
     (if print
         (crest-make-static-c-callable (uptr uptr) scheme-object (lambda (op printer) (print op printer op-name)))
         0)
     (if fold (%%fold-entry-point fold) 0)
     (if get-canonicalization-patterns
         (crest-make-static-c-callable (uptr) scheme-object get-canonicalization-patterns)
         0)
     (if populate-default-attrs
         (crest-make-static-c-callable (uptr uptr) scheme-object populate-default-attrs)
         0)
     traits))

  ;; The slots of a type: verify, parse, print. An error that a procedure raises is answered to C++ as
  ;; (who . why) by the callable, and C++ reports it.
  ;;   verify  (params) → #t | #f | a message. C: 1, 0 (MLIR's message) or 2 (the message is in sink)
  ;;   parse   (parser) → a list of attributes | #f. C: 1 (the parameters are in sink), 0
  ;;   print   (printer params). C gets the parameters as a pointer and a count
  (define (crest-type-callback-entries verify parse print)
    (vector
     (if verify
         (crest-make-static-c-callable
          (uptr uptr uptr) scheme-object
          (lambda (params count sink)
            (let ([answer (verify (crest-callback-pointer-list params count))])
              (cond
               [(string? answer) (%crest::DynamicType::setMessage sink answer) 2]
               [answer 1]
               [else 0]))))
         0)
     (if parse
         (crest-make-static-c-callable
          (uptr uptr) scheme-object
          (lambda (parser sink)
            (let ([parsed (parse parser)])
              (cond
               [parsed
                (for-each (lambda (attribute) (%crest::DynamicType::addParam sink attribute))
                          parsed)
                1]
               [else 0]))))
         0)
     (if print
         (crest-make-static-c-callable
          (uptr uptr uptr) scheme-object
          (lambda (printer params count)
            (print printer (crest-callback-pointer-list params count))))
         0)))

  ) ;; end library (crest dialect callbacks)
