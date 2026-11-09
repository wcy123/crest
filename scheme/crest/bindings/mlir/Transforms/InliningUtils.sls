#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Transforms InliningUtils) — Public API for mlir/Transforms/InliningUtils.h.
;;
;; Provides:
;;   mlir::DialectInlinerInterface — register a Scheme-backed inliner interface
;;                                    on a CrestDialect
;;   mlir::createInlinerPass       — create an MLIR inliner pass instance
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Transforms InliningUtils)
  (export mlir::DialectInlinerInterface
          mlir::DialectInlinerInterface::materializeCallConversion
          mlir::createInlinerPass)
  (import (chezscheme)
          (crest callback)
          (mlir Transforms InliningUtils ffi))

  (define (%%required dispatcher name)
    (or (dispatcher name)
        (error 'mlir::DialectInlinerInterface
               (string-append (symbol->string name) " is required but not provided"))))

  ;; The foreign-callables of one dispatcher, as the list of their entry points that
  ;; %mlir::DialectInlinerInterface takes. The dispatcher is a procedure of the dialect's library,
  ;; so it is the same object each time a context loads the dialect: its callables are made once
  ;; and shared by all contexts.
  (define %%entries (make-weak-eq-hashtable))

  (define (%%make-entries dispatcher)
    (let ([call   (%%required dispatcher 'isLegalToInline/call)]
          [region (%%required dispatcher 'isLegalToInline/region)]
          [op     (%%required dispatcher 'isLegalToInline/op)]
          [value  (dispatcher 'handleTerminator/value)]
          [block  (dispatcher 'handleTerminator/block)]
          [materialize (dispatcher 'materializeCallConversion)])
      (list
       (crest-callback-entry-point
        (uptr uptr int) int
        (lambda (call-op callable would-be-cloned)
          (if (call call-op callable (eqv? would-be-cloned 1)) 1 0)))
       (crest-callback-entry-point
        (uptr uptr int) int
        (lambda (dest src would-be-cloned)
          (if (region dest src (eqv? would-be-cloned 1)) 1 0)))
       (crest-callback-entry-point
        (uptr uptr int) int
        (lambda (inlined-op dest would-be-cloned)
          (if (op inlined-op dest (eqv? would-be-cloned 1)) 1 0)))
       (if value (crest-callback-entry-point (uptr uptr) void value) 0)
       (if block (crest-callback-entry-point (uptr uptr) void block) 0)
       (if materialize
           (crest-callback-entry-point
            (uptr uptr uptr uptr) uptr
            (lambda (builder input result-type loc)
              (or (materialize builder input result-type loc) 0)))
           0))))

  ;; @brief Register the inliner interface of a Scheme dialect.
  ;; @param dialect     the dialect (CrestDialect*) uptr
  ;; @param dispatcher  made by define-dialect for its :interfaces entry: answers a method name with
  ;;                    the clause or #f; isLegalToInline/call, /region and /op are required
  (define (mlir::DialectInlinerInterface dialect dispatcher)
    (let ([entries (or (hashtable-ref %%entries dispatcher #f)
                       (let ([made (%%make-entries dispatcher)])
                         (hashtable-set! %%entries dispatcher made)
                         made))])
      (apply %mlir::DialectInlinerInterface dialect entries)))

  ;; @brief materializeCallConversion on the dialect's inliner interface: creates the op that
  ;; bridges a call operand of one type to a parameter of another.
  ;; @param builder      builder shell (any kind)
  ;; @param dialect      mlir::Dialect* uptr
  ;; @param input        mlir::Value uptr
  ;; @param result-type  mlir::Type uptr
  ;; @param loc          mlir::Location uptr
  ;; @return             mlir::Operation* uptr, or 0 when none
  (define mlir::DialectInlinerInterface::materializeCallConversion
    %mlir::DialectInlinerInterface::materializeCallConversion)

  (define mlir::createInlinerPass %mlir::createInlinerPass)

  ) ;; end library (mlir Transforms InliningUtils)
