#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest affine-map) — the affine-map macro.
;;
;;   (affine-map (dim ...) (sym ...) result ...)
;;
;; Builds an mlir::AffineMap. Inside the body each dim is let-bound to its dimension
;; expression and each sym to its symbol expression, by position, and + - * floordiv ceildiv
;; mod are rebound to the AffineExpr operators of (mlir IR AffineExpr). The body is plain
;; Scheme, so any variable in scope is visible. A result is an AffineExpr or an integer (a
;; constant). The context is (current-MLIRContext). See docs/affine-map-dsl.md.
;;
;;===----------------------------------------------------------------------===;;

(library (crest affine-map)
  (export affine-map)
  (import (rnrs)
          (for (rnrs) expand)
          (for (only (chezscheme) syntax->list) expand)
          (only (mlir IR AffineExpr)
                mlir::getAffineDimExpr
                mlir::getAffineSymbolExpr
                mlir::AffineExpr::operator+
                mlir::AffineExpr::operator-
                mlir::AffineExpr::operator*
                mlir::AffineExpr::floorDiv
                mlir::AffineExpr::ceilDiv
                mlir::AffineExpr::operator%)
          (only (mlir IR AffineMap) mlir::AffineMap::get))

  (define-syntax affine-map
    (lambda (stx)
      (define operator-names '(+ - * floordiv ceildiv mod))

      ;; (0 1 ... n-1)
      (define (positions n)
        (let loop ([i (- n 1)] [acc '()])
          (if (< i 0) acc (loop (- i 1) (cons i acc)))))

      ;; Raise a syntax error at the first name that is not an identifier, is repeated, or is
      ;; an operator name.
      (define (check-names! names)
        (let loop ([rest names])
          (unless (null? rest)
            (let ([name (car rest)])
              (unless (identifier? name)
                (syntax-violation 'affine-map "dimension and symbol names must be identifiers" stx name))
              (when (memq (syntax->datum name) operator-names)
                (syntax-violation 'affine-map "a name cannot be an operator name" stx name))
              (when (exists (lambda (other) (bound-identifier=? name other)) (cdr rest))
                (syntax-violation 'affine-map "a dimension or symbol name is repeated" stx name))
              (loop (cdr rest))))))

      (syntax-case stx ()
        [(k (dim ...) (sym ...) result ...)
         (let ([dims (syntax->list #'(dim ...))]
               [syms (syntax->list #'(sym ...))])
           (check-names! (append dims syms))
           (with-syntax ([(dim-position ...) (positions (length dims))]
                         [(sym-position ...) (positions (length syms))]
                         [ndims (length dims)]
                         [nsyms (length syms)]
                         [op+ (datum->syntax #'k '+)]
                         [op- (datum->syntax #'k '-)]
                         [op* (datum->syntax #'k '*)]
                         [op-floordiv (datum->syntax #'k 'floordiv)]
                         [op-ceildiv (datum->syntax #'k 'ceildiv)]
                         [op-mod (datum->syntax #'k 'mod)])
             #'(let ([dim (mlir::getAffineDimExpr dim-position)] ...
                     [sym (mlir::getAffineSymbolExpr sym-position)] ...
                     [op+ mlir::AffineExpr::operator+]
                     [op- mlir::AffineExpr::operator-]
                     [op* mlir::AffineExpr::operator*]
                     [op-floordiv mlir::AffineExpr::floorDiv]
                     [op-ceildiv mlir::AffineExpr::ceilDiv]
                     [op-mod mlir::AffineExpr::operator%])
                 (mlir::AffineMap::get ndims nsyms (list result ...)))))])))

  ) ;; end library (crest affine-map)
