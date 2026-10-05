#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir rewriter-base) — RewriterBase user-visible API.
;;
;; Mirrors mlir/IR/PatternMatch.h RewriterBase.
;; Re-exports clean names from (mlir ir rewriter-base ffi).
;; Also provides dynamic parameters and RAII macros for builder context.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir rewriter-base)
  (export
    ;; Clean-name re-exports from ffi
    rewriter-base-create
    rewriter-base-create-with-regions
    rewriter-base-set-insertion-point-before
    rewriter-base-set-insertion-point-to-end
    rewriter-base-create-block
    rewriter-base-replace-op
    rewriter-base-erase-op
    rewriter-base-clone-with-types
    ;; Dynamic builder context
    current-rewriter
    current-block-builder
    current-loc
    ;; Context-dispatching constructor
    mlir-build-operation
    ;; RAII macros
    with-raii
    with-rewrite-builder
    with-current-block-builder
    with-block-builder
    with-op-location)

  (import (rnrs)
          (only (chezscheme) make-parameter parameterize void)
          (mlir ir rewriter-base ffi)
          (mlir ir op-builder ffi)
          (only (mlir core context) current-mlir-context)
          (only (mlir core operation) mlir-operation-get-context))

  (define rewriter-base-create                   %rewriter-base-create)
  (define rewriter-base-create-with-regions      %rewriter-base-create-with-regions)
  (define rewriter-base-set-insertion-point-before %rewriter-base-set-insertion-point-before)
  (define rewriter-base-set-insertion-point-to-end %rewriter-base-set-insertion-point-to-end)
  (define rewriter-base-create-block             %rewriter-base-create-block)
  (define rewriter-base-replace-op               %rewriter-base-replace-op)
  (define rewriter-base-erase-op                 %rewriter-base-erase-op)
  (define rewriter-base-clone-with-types         %rewriter-base-clone-with-types)

  ;; Dynamic builder context
  (define current-rewriter      (make-parameter #f))
  (define current-block-builder (make-parameter #f))
  (define current-loc           (make-parameter #f))

  ;; Context-dispatching op constructor
  (define (mlir-build-operation name operands types . rest)
    (let ([nregions (if (pair? rest) (car rest) 0)]
          [loc      (current-loc)])
      (cond
        [(current-rewriter) =>
         (lambda (rw)
           (if (zero? nregions)
               (%rewriter-base-create rw loc name operands types)
               (%rewriter-base-create-with-regions rw loc name operands types nregions)))]
        [(current-block-builder) =>
         (lambda (b)
           (if (zero? nregions)
               (%op-builder-create b loc name operands types)
               (%op-builder-create-with-regions b loc name operands types nregions)))]
        [else (error 'mlir-build-operation "no current builder installed")])))

  (define-syntax with-raii
    (syntax-rules ()
      [(_ (var ctor dtor) body ...)
       (let ([var ctor])
         (dynamic-wind void
           (lambda () body ...)
           (lambda () (dtor var))))]))

  (define-syntax with-rewrite-builder
    (syntax-rules ()
      [(_ (rw loc) body ...)
       (parameterize ([current-rewriter      rw]
                      [current-block-builder #f]
                      [current-loc           loc]
                      [current-mlir-context  (mlir-operation-get-context loc)])
         body ...)]))

  (define-syntax with-current-block-builder
    (syntax-rules ()
      [(_ (builder loc) body ...)
       (parameterize ([current-block-builder builder]
                      [current-rewriter      #f]
                      [current-loc           loc]
                      [current-mlir-context  (mlir-operation-get-context loc)])
         body ...)]))

  (define-syntax with-block-builder
    (syntax-rules ()
      [(_ block body ...)
       (let ([%builder (%op-builder-at-block-end block)])
         (dynamic-wind
           (lambda () #f)
           (lambda ()
             (parameterize ([current-block-builder %builder]
                            [current-rewriter #f])
               body ...))
           (lambda () (%op-builder-destroy %builder))))]))

  (define-syntax with-op-location
    (syntax-rules ()
      [(_ loc body ...)
       (parameterize ([current-loc loc]) body ...)]))

) ;; end library (mlir ir rewriter-base)
