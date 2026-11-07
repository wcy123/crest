#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest pass) — define-pass: a pass written in Scheme.
;;
;;   (define-pass (name op)
;;     body ...)
;;
;; defines the procedure (name), which makes a new mlir::Pass every time it is called (a pass is
;; consumed by PassManager::addPass). When the pass runs, op is the operation it is anchored on (the
;; PassManager it is added to decides which: nest "toy.func" runs it on each toy.func) and body runs;
;; a body that returns #f fails the pass, anything else is success. A failing body should say why with
;; mlir::Operation::emitError first.
;;
;;   (with-PassManager pm (ctx)
;;     (let ([func-pm (mlir::PassManager::nest pm "toy.func")])
;;       (mlir::OpPassManager::addPass func-pm (shape-inference)))
;;     (mlir::PassManager::run! pm module-op))
;;
;; Scheme is single-threaded: a context made from Scheme already has multithreading disabled; for
;; crest-opt pass --mlir-disable-threading.
;;
;;===----------------------------------------------------------------------===;;

(library (crest pass)
  (export define-pass)
  (import (rnrs)
          (for (only (chezscheme) syntax->list) expand)
          (crest pass ffi))

  (define-syntax define-pass
    (lambda (stx)
      (syntax-case stx ()
        [(_ (name op) body ...)
         (and (identifier? #'name) (identifier? #'op))
         (with-syntax ([name-string (symbol->string (syntax->datum #'name))])
           #'(define (name)
               (%crest::createSchemePass name-string (lambda (op) body ...))))]
        [(_ . _)
         (syntax-violation 'define-pass "expected (define-pass (name op) body ...)" stx)])))

  ) ;; end library (crest pass)
