#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest define-pass) — define-pass: a pass written in Scheme.
;;
;;   (define-pass (name op)
;;     body ...)
;;
;; defines the procedure (name), which makes a new crest::SchemePass object every time (name) is
;; called (PassManager::addPass consumes a crest::SchemePass object). When the pass runs, op is the
;; address of the mlir::Operation object that the pass is anchored on (the PassManager that the
;; crest::SchemePass object is added to decides which: nest "toy.func" runs the pass on each
;; toy.func) and body runs;
;; a body that returns #f fails the pass, anything else is success. A failing body should say why with
;; mlir::Operation::emitError first. An error that the body raises does not end the process: the pass
;; fails and the diagnostic has the text of the error.
;;
;; The body is made into a C function, once, where the pass is defined; every pass that (name) makes
;; calls it.
;;
;;   (with-PassManager pm (ctx)
;;     (let ([func-pm (mlir::PassManager::nest pm "toy.func")])
;;       (mlir::OpPassManager::addPass func-pm (shape-inference)))
;;     (mlir::PassManager::run! pm module-op))
;;
;; A pass nested on func.func can run on several threads of MLIR at once: see "Threads" in docs/manual.md.
;;
;;===----------------------------------------------------------------------===;;

(library (crest define-pass)
  (export define-pass
          define-pass-entry-point)
  (import (rnrs)
          (for (only (chezscheme) syntax->list) expand)
          (crest callback)
          (crest pass))

  ;; define-pass: write a pass as its body, and let the macro do the plumbing.
  ;;
  ;; A PassManager runs crest::SchemePass objects. PassManager::addPass takes the address of a
  ;; crest::SchemePass object, and owns the crest::SchemePass object from then on, so each use needs a
  ;; new crest::SchemePass object. A body written in Scheme is not a crest::SchemePass object:
  ;; crest::createSchemePass makes a crest::SchemePass object for the body. crest::SchemePass derives
  ;; from mlir::OperationPass<>, and mlir::OperationPass<> derives from mlir::Pass
  ;; (mlir/Pass/Pass.h), so the PassManager treats a crest::SchemePass object as an mlir::Pass object.
  ;; When MLIR runs the crest::SchemePass object, the object calls a C function with the address of
  ;; the mlir::Operation object that the pass runs on, and the C function returns 1 (success) or 0
  ;; (failure). That C function is the body. By hand that is three things: the C function with the
  ;; right prototype, made once and kept for good; a procedure that makes a new crest::SchemePass
  ;; object for that C function each time the procedure is called; and the name of the pass as a
  ;; string. define-pass makes all three from the body.
  ;;
  ;; Input
  ;;   name  the identifier to define, and the name of the pass: (name) makes a crest::SchemePass
  ;;         object whose name is "name"
  ;;   op    the variable that the body sees: the address of the mlir::Operation object that the
  ;;         pass runs on
  ;;   body  what the pass does. #f fails the pass, any other value is success. The body is wrapped
  ;;         in (let () ...), so the body can begin with definitions.
  ;;
  ;; Why define-pass exists: the body of a pass is called from C++, and C++ and Scheme do not check each
  ;; other. A mistake at this boundary is not an error with a message: it crashes the process.
  ;; define-pass does the delicate parts, so the end user writes only the body:
  ;;   - the prototype of the C function. C++ calls int (*)(uint64_t op), and nothing checks that the
  ;;     Scheme side declares the same types. A mismatch crashes. define-pass declares (op uptr) int.
  ;;   - the value of the body. #f becomes 0 and any other value becomes 1, so the body cannot return
  ;;     a wrong C value.
  ;;
  ;; The macro also defines the hidden name entry for the C function, once for each use of define-pass,
  ;; and takes the name of the pass from the identifier name.
  ;;
  ;; What stays with the end user: adding the crest::SchemePass object to a PassManager. A
  ;; crest::SchemePass object that is never added leaks.
  ;;
  ;; crest::createSchemePass, the procedure that makes the crest::SchemePass object, is described
  ;; where (crest pass) defines it.
  ;;
  ;; Example
  ;;   Before:
  ;;     (define-pass (tag-functions op)
  ;;       (mlir::Operation::setAttr! op "tagged"
  ;;         (mlir::StringAttr::get (mlir::Operation::getContext op) "yes"))
  ;;       #t)
  ;;   After (the expansion; entry is the hidden name):
  ;;     (begin
  ;;       (define-c-callable entry ((op uptr)) int
  ;;         (if (let ()
  ;;               (mlir::Operation::setAttr! op "tagged"
  ;;                 (mlir::StringAttr::get (mlir::Operation::getContext op) "yes"))
  ;;               #t)
  ;;             1
  ;;             0))
  ;;       (define (tag-functions)
  ;;         (crest::createSchemePass "tag-functions" entry)))
  ;;   Used (every call of (tag-functions) makes a new crest::SchemePass object):
  ;;     (mlir::OpPassManager::addPass func-pm (tag-functions))
  (define-syntax define-pass
    (lambda (stx)
      (syntax-case stx ()
        [(_ (name op) body ...)
         (and (identifier? #'name) (identifier? #'op))
         (with-syntax ([name-string (symbol->string (syntax->datum #'name))])
           #'(begin
               ;; 1 or 0 for C; an error of the body is reported at the variable op, and returns 0.
               (define-c-callable entry ((op uptr)) int
                 (if (let () body ...) 1 0))
               (define (name)
                 (crest::createSchemePass name-string entry))))]
        [(_ . _)
         (syntax-violation 'define-pass "expected (define-pass (name op) body ...)" stx)])))

  ) ;; end library (crest define-pass)
