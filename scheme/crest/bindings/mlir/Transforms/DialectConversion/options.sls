#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Transforms DialectConversion options) — expand-time helpers for the options of
;; with-TypeConverter and with-ConversionTarget, which are written (:keyword value ...).
;; CREST-specific, no MLIR counterpart.
;;
;;===----------------------------------------------------------------------===;;
(library (mlir Transforms DialectConversion options)
  (export conversion-options
          conversion-option-list
          conversion-keyword?)
  (import (rnrs)
          (only (chezscheme) syntax->list))

  ;; The options as an alist of (keyword . value syntax). An unknown keyword, or a keyword without a
  ;; value, is an error when the program compiles.
  (define (conversion-options who stx items allowed)
    (let loop ([rest items] [options '()])
      (cond
       [(null? rest) (reverse options)]
       [(not (memq (syntax->datum (car rest)) allowed))
        (syntax-violation who "unknown option: the options are" stx (car rest))]
       [(null? (cdr rest))
        (syntax-violation who "the option needs a value" stx (car rest))]
       [else (loop (cddr rest)
                   (cons (cons (syntax->datum (car rest)) (cadr rest)) options))])))

  ;; The elements of the list that the option has as its value (none when it is absent).
  (define (conversion-option-list options keyword)
    (let ([found (assq keyword options)])
      (if found (syntax->list (cdr found)) '())))

  (define (conversion-keyword? x)
    (let ([d (syntax->datum x)])
      (and (symbol? d)
           (let ([name (symbol->string d)])
             (and (> (string-length name) 1) (char=? (string-ref name 0) #\:))))))

  ) ;; end library (mlir Transforms DialectConversion options)
