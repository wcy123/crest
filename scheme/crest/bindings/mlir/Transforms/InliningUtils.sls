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
          (for (mlir support srcloc) expand)
          (mlir Transforms InliningUtils ffi))

  (define (%%required dispatcher name)
    (or (dispatcher name)
        (error 'mlir::DialectInlinerInterface
               (string-append (symbol->string name) " is required but not provided"))))

  ;; The C functions of the clauses of a dialect. `dispatcher` is (lambda (method) ...): a method
  ;; name answers its clause or #f; a clause is the pair (procedure . position), the position of the
  ;; clause in the Scheme source, (file line column) or #f, where an error of the procedure is
  ;; reported; isLegalToInline/call, /region and /op are required. The answer
  ;; is the dispatcher of C: (lambda (method) ...) that answers, for each method the dispatcher has
  ;; a clause for, the entry point of its foreign-callable, and 0 for the others. The callables are
  ;; made here, once: the entry of the :interfaces clause is evaluated when the library of the dialect
  ;; is loaded, and C++ gets the dispatcher with the TypeID of the interface, asks it for the entries
  ;; while it loads the dialect in a context, and gives the dialect its inliner interface
  ;; (lib/Crest/InlinerInterface.cpp). It does not keep the dispatcher.
  (define (%%c-dispatcher dispatcher)
    (let ([call   (%%required dispatcher 'isLegalToInline/call)]
          [region (%%required dispatcher 'isLegalToInline/region)]
          [op     (%%required dispatcher 'isLegalToInline/op)]
          [value  (dispatcher 'handleTerminator/value)]
          [block  (dispatcher 'handleTerminator/block)]
          [materialize (dispatcher 'materializeCallConversion)])
      (let ([entries
             (list
              (cons 'isLegalToInline/call
                    (crest-make-static-c-callable
                     (uptr uptr int) int
                     (lambda (call-op callable would-be-cloned)
                       (if ((car call) call-op callable (eqv? would-be-cloned 1)) 1 0))
                     :location (cdr call)))
              (cons 'isLegalToInline/region
                    (crest-make-static-c-callable
                     (uptr uptr int) int
                     (lambda (dest src would-be-cloned)
                       (if ((car region) dest src (eqv? would-be-cloned 1)) 1 0))
                     :location (cdr region)))
              (cons 'isLegalToInline/op
                    (crest-make-static-c-callable
                     (uptr uptr int) int
                     (lambda (inlined-op dest would-be-cloned)
                       (if ((car op) inlined-op dest (eqv? would-be-cloned 1)) 1 0))
                     :location (cdr op)))
              (cons 'handleTerminator/value
                    (if value
                        (crest-make-static-c-callable (uptr uptr) void (car value) :location (cdr value))
                        0))
              (cons 'handleTerminator/block
                    (if block
                        (crest-make-static-c-callable (uptr uptr) void (car block) :location (cdr block))
                        0))
              (cons 'materializeCallConversion
                    (if materialize
                        (crest-make-static-c-callable
                         (uptr uptr uptr uptr) uptr
                         (lambda (builder input result-type loc)
                           (or ((car materialize) builder input result-type loc) 0))
                         :location (cdr materialize))
                        0)))])
        (lambda (method)
          (cond
           [(assq method entries) => cdr]
           [else 0])))))

  ;; An entry of the :interfaces clause of define-dialect (the dialect's own, not an op's):
  ;;   (mlir::DialectInlinerInterface
  ;;     (isLegalToInline/call   (call callable would-be-cloned) body ...)   required
  ;;     (isLegalToInline/region (dest src would-be-cloned) body ...)        required
  ;;     (isLegalToInline/op     (op dest would-be-cloned) body ...)         required
  ;;     (handleTerminator/value (op replacements) body ...)
  ;;     (handleTerminator/block (op new-dest) body ...)
  ;;     (materializeCallConversion (builder input result-type loc) body ...))
  ;; An entry is the pair of the TypeID of the interface and the dispatcher of C of its clauses.
  (define-syntax mlir::DialectInlinerInterface
    (lambda (stx)
      (syntax-case stx ()
        [(_ (method (formal ...) body ...) ...)
         (with-syntax ([(position ...)
                        (map (lambda (clause)
                               (datum->syntax #'stx (syntax->first-file+line+col clause)))
                             (syntax->list #'((method (formal ...) body ...) ...)))])
           #'(cons (mlir::DialectInlinerInterface::getInterfaceID)
                   (%%c-dispatcher
                    (lambda (name)
                      (case name
                        [(method) (cons (lambda (formal ...) body ...) 'position)] ...
                        [else #f])))))])))

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
