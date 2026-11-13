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
;;   mlir::DialectInlinerInterface — the head of an entry of the :interfaces clause of
;;                                    define-dialect: a Scheme-backed inliner interface
;;   mlir::createInlinerPass       — create an MLIR inliner pass instance
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Transforms InliningUtils)
  (export mlir::DialectInlinerInterface
          mlir::DialectInlinerInterface::getInterfaceID
          mlir::DialectInlinerInterface::materializeCallConversion
          mlir::createInlinerPass)
  (import (chezscheme)
          (crest callback)
          (only (crest interface) crest-callback-entry-dispatcher)
          (mlir Transforms InliningUtils ffi))

  ;; An entry of the :interfaces clause of define-dialect (the dialect's own, not an op's):
  ;;   (mlir::DialectInlinerInterface
  ;;     (isLegalToInline/call   (call callable would-be-cloned) body ...)   required
  ;;     (isLegalToInline/region (dest src would-be-cloned) body ...)        required
  ;;     (isLegalToInline/op     (op dest would-be-cloned) body ...)         required
  ;;     (handleTerminator/value (op replacements) body ...)
  ;;     (handleTerminator/block (op new-dest) body ...)
  ;;     (materializeCallConversion (builder input result-type loc) body ...))
  ;; An entry is the pair of the TypeID of the interface and the dispatcher of C of its clauses: from a
  ;; method name to the entry point of its callable, 0 for a method without a clause.
  ;; The callable of each clause is made here, in the expansion, once: the entry of the :interfaces clause
  ;; is evaluated when the library of the dialect is loaded, and C++ gets the dispatcher with the TypeID
  ;; of the interface, asks it for the entries while it loads the dialect in a context, and gives the
  ;; dialect its inliner interface (lib/Crest/InlinerInterface.cpp). It does not keep the dispatcher. The
  ;; prototypes are those of lib/Crest/InlinerInterface.h; the clause is in the form that the callable is
  ;; made from, so an error is reported at the position of the clause.
  (define-syntax mlir::DialectInlinerInterface
    (lambda (stx)
      (define required '(isLegalToInline/call isLegalToInline/region isLegalToInline/op))
      (define (entry clause)
        (syntax-case clause ()
          [(method (formal ...) body ...)
           (case (syntax->datum #'method)
             [(isLegalToInline/call isLegalToInline/region isLegalToInline/op)
              #'(cons 'method
                      (let ()
                        (define-c-callable address ((first uptr) (second uptr) (would-be-cloned int)) int
                          (if ((lambda (formal ...) body ...) first second (eqv? would-be-cloned 1)) 1 0))
                        address))]
             [(handleTerminator/value handleTerminator/block)
              #'(cons 'method
                      (let ()
                        (define-c-callable address ((first uptr) (second uptr)) void
                          ((lambda (formal ...) body ...) first second))
                        address))]
             [(materializeCallConversion)
              #'(cons 'method
                      (let ()
                        (define-c-callable address
                          ((builder uptr) (input uptr) (result-type uptr) (loc uptr)) uptr
                          (or ((lambda (formal ...) body ...) builder input result-type loc) 0))
                        address))]
             [else
              (syntax-violation 'mlir::DialectInlinerInterface "has no method of this name" stx clause)])]
          [_ (syntax-violation 'mlir::DialectInlinerInterface
                               "clauses are written (method (formal ...) body ...)" stx clause)]))
      (syntax-case stx ()
        [(_ clause ...)
         (let ([given (map (lambda (clause) (syntax->datum (car (syntax->list clause))))
                           (syntax->list #'(clause ...)))])
           (for-each
            (lambda (name)
              (unless (memq name given)
                (syntax-violation 'mlir::DialectInlinerInterface
                                  (string-append (symbol->string name) " is required but not provided")
                                  stx)))
            required)
           (with-syntax ([(entry ...) (map entry (syntax->list #'(clause ...)))])
             #'(cons (mlir::DialectInlinerInterface::getInterfaceID)
                     (crest-callback-entry-dispatcher (list entry ...)))))])))

  (define mlir::DialectInlinerInterface::getInterfaceID
    %mlir::DialectInlinerInterface::getInterfaceID)

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
