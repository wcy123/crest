#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest patterns expand) — expansion-time helpers of apply-patterns and define-pattern-set.
;;
;;===----------------------------------------------------------------------===;;

(library (crest patterns expand)
  (export list-of pattern-entry pattern-entry-form)
  (import (rnrs)
          (only (chezscheme) syntax->list)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern))

  ;; The elements of a proper list form, #f for anything else.
  (define (list-of x)
    (syntax-case x ()
      [(e ...) (syntax->list x)]
      [_ #f]))

  ;; (name pattern [benefit]) → the entry (name pattern benefit) of the :rewrite-patterns clause of
  ;; with-RewritePatternSet. who is the macro's name for the error message.
  (define (pattern-entry who entry)
    (let ([parts (or (list-of entry) '())])
      (unless (and (>= (length parts) 2) (<= (length parts) 3))
        (syntax-violation who "a pattern is (name pattern [benefit])" entry))
      #`(#,(car parts) #,(cadr parts) #,(if (null? (cddr parts)) #'1 (caddr parts)))))

  ;; (name pattern [benefit]) → the form that registers it in the set named by patterns, where the
  ;; pattern is a callable (what define-rewrite-pattern defines).
  (define (pattern-entry-form who entry patterns)
    (syntax-case (pattern-entry who entry) ()
      [(name pattern benefit) #`(add-rewrite-pattern #,patterns name pattern benefit)]))

  ) ;; end library (crest patterns expand)
