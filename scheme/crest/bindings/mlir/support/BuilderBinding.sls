#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support BuilderBinding) — define-builder-binding, the Scheme side of
;; lib/Bindings/Support/BuilderBinding.h.
;;
;; A builder is one of three shells, and each C++ symbol takes exactly one:
;;
;;   NAME<OpBuilder>      CrestBox<mlir::OpBuilder>      (atBlockEnd)
;;   NAME<RewriterBase*>  CrestBox<mlir::RewriterBase*>  (a pattern's rewriter)
;;   NAME<OpBuilder*>     CrestBox<mlir::OpBuilder*>     (a builder MLIR passes to a callback)
;;
;; A NAME that already ends in '>' takes the kind as its last template argument:
;; "mlir::OpBuilder::create<OperationState>" gives "...<OperationState,OpBuilder>".
;; define-builder-binding makes one procedure that checks the shell's type and calls the
;; matching symbol, so callers pass whichever builder they hold.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support BuilderBinding)
  (export define-builder-binding)

  (import (rnrs)
          (for (rnrs) expand)
          (only (chezscheme) foreign-procedure))

  (define %isa-builder?
    (let ([f (foreign-procedure "crest::isa<CrestBox<mlir::OpBuilder>>" (uptr) int)])
      (lambda (p) (not (zero? (f p))))))

  (define %isa-rewriter?
    (let ([f (foreign-procedure "crest::isa<CrestBox<mlir::RewriterBase*>>" (uptr) int)])
      (lambda (p) (not (zero? (f p))))))

  (define %isa-borrowed?
    (let ([f (foreign-procedure "crest::isa<CrestBox<mlir::OpBuilder*>>" (uptr) int)])
      (lambda (p) (not (zero? (f p))))))

  ;; @brief define-builder-binding — define VAR as a procedure over the three builder variants.
  ;; @param var    the name to define, normally the raw FFI name with the % prefix
  ;; @param name   string literal: the C++ name, the common part of the three symbols
  ;; @param types  (builder-type arg-type ...) as for foreign-procedure; the first is the builder
  ;; @param ret    the return type
  ;; @example
  ;;   (define-builder-binding %mlir::arith::AddFOp::create
  ;;     "mlir::arith::AddFOp::create" (uptr uptr uptr uptr) uptr)
  (define-syntax define-builder-binding
    (lambda (stx)
      (define (with-kind name kind)
        (let ([n (string-length name)])
          (if (and (> n 0) (char=? (string-ref name (- n 1)) #\>))
              (string-append (substring name 0 (- n 1)) "," kind ">")
              (string-append name "<" kind ">"))))
      (syntax-case stx ()
        [(_ var name (builder-type arg-type ...) ret)
         (and (identifier? #'var) (string? (syntax->datum #'name)))
         (with-syntax ([sym-builder  (datum->syntax #'var (with-kind (syntax->datum #'name) "OpBuilder"))]
                       [sym-rewriter (datum->syntax #'var (with-kind (syntax->datum #'name) "RewriterBase*"))]
                       [sym-borrowed (datum->syntax #'var (with-kind (syntax->datum #'name) "OpBuilder*"))]
                       [(arg ...) (generate-temporaries #'(arg-type ...))])
           #'(define var
               (let ([call-builder  (foreign-procedure sym-builder  (builder-type arg-type ...) ret)]
                     [call-rewriter (foreign-procedure sym-rewriter (builder-type arg-type ...) ret)]
                     [call-borrowed (foreign-procedure sym-borrowed (builder-type arg-type ...) ret)])
                 (lambda (builder arg ...)
                   (cond
                    [(%isa-rewriter? builder) (call-rewriter builder arg ...)]
                    [(%isa-builder? builder)  (call-builder builder arg ...)]
                    [(%isa-borrowed? builder) (call-borrowed builder arg ...)]
                    [else (error 'name
                                 "expected a builder: CrestBox<RewriterBase*>, CrestBox<OpBuilder> or CrestBox<OpBuilder*>"
                                 builder)])))))])))

  ) ;; end library (mlir support BuilderBinding)
