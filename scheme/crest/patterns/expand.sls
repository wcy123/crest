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
  (export list-of pattern-entry-form)
  (import (rnrs)
          (only (chezscheme) syntax->list)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern))

  ;; The elements of a proper list form, #f for anything else.
  (define (list-of x)
    (syntax-case x ()
      [(e ...) (syntax->list x)]
      [_ #f]))

  ;; (name pattern [benefit]) → the form that registers it in the set named by patterns.
  ;; who is the macro's name for the error message.
  (define (pattern-entry-form who entry patterns)
    (let ([parts (or (list-of entry) '())])
      (unless (and (>= (length parts) 2) (<= (length parts) 3))
        (syntax-violation who "a pattern is (name pattern [benefit])" entry))
      #`(add-rewrite-pattern #,patterns #,(car parts) #,(cadr parts)
                             #,(if (null? (cddr parts)) #'1 (caddr parts)))))

  ) ;; end library (crest patterns expand)
