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

(library (crest pass)
  (export define-pass
          define-pass-entry-point
          crest::createSchemePass)
  (import (rnrs)
          (for (only (chezscheme) syntax->list) expand)
          (crest callback)
          (crest pass ffi))

  ;; define-pass: write a pass as its body, and let the macro do the plumbing.
  ;;
  ;; MLIR runs a pass by calling a C function with the address of the operation, and wants 1 (success)
  ;; or 0 (failure) back. PassManager::addPass also consumes the pass it is given, so each use needs a
  ;; new one. By hand that is a C function with the right prototype, made once and kept for good, a
  ;; procedure that makes a pass from it, and the name of the pass as a string. define-pass makes all
  ;; three from the body.
  ;;
  ;; Input
  ;;   name  the identifier to define, and the name of the pass: (name) makes a pass called "name"
  ;;   op    the variable that the body sees: the operation the pass runs on
  ;;   body  what the pass does. #f fails the pass, any other value is success. It is wrapped in
  ;;         (let () ...), so it can begin with definitions.
  ;;
  ;; Why a macro, and not a procedure that takes the body:
  ;;   - it defines names: name, and a hidden entry for the C function. Each use has its own entry,
  ;;     so one library can hold many passes.
  ;;   - the name of the pass is the identifier as it is written. A procedure does not know the name
  ;;     that it is bound to.
  ;;   - the position of the body is read from its syntax, so an error of the body is reported where
  ;;     the body is written (define-c-callable in (crest callback) does it).
  ;;
  ;; The pass itself is made by crest::createSchemePass. This library exports it under that name: it
  ;; is %crest::createSchemePass of (crest pass ffi), which calls lib/Crest/SchemePass.cpp. It takes
  ;; the name string and entry, the address of the C function of the body, and returns a new
  ;; mlir::Pass. That pass runs on any operation: the PassManager it is added to decides which. When
  ;; it runs, it calls entry with the address of the operation, and 0 fails the pass. Once the pass
  ;; is added, the PassManager owns it. A pass that is made and never added leaks.
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
  ;;   Used (every call makes a new pass):
  ;;     (mlir::OpPassManager::addPass func-pm (tag-functions))
  (define-syntax define-pass
    (lambda (stx)
      (syntax-case stx ()
        [(_ (name op) body ...)
         (and (identifier? #'name) (identifier? #'op))
         (with-syntax ([name-string (symbol->string (syntax->datum #'name))])
           #'(begin
               ;; 1 or 0 for C; an error of the body is reported at the body, and returns 0.
               (define-c-callable entry ((op uptr)) int
                 (if (let () body ...) 1 0))
               (define (name)
                 (crest::createSchemePass name-string entry))))]
        [(_ . _)
         (syntax-violation 'define-pass "expected (define-pass (name op) body ...)" stx)])))

  ;; @brief crest::createSchemePass — make a pass that runs the body of a define-pass.
  ;; @param name   the name of the pass, a string: what getName returns
  ;; @param entry  the address of the C function that define-pass made for the body, int (uptr op).
  ;;               The pass calls it with the address of the operation that it runs on
  ;; @return       the address of a new mlir::Pass
  ;; @note         It makes a new SchemePass (lib/Crest/SchemePass.cpp), an mlir::OperationPass that
  ;;               holds a copy of name and the pointer entry, and nothing else. getName returns
  ;;               name, and cloning the pass copies both.
  ;;               The pass runs on any operation: the PassManager it is added to decides which
  ;;               (nest "toy.func" runs it on each toy.func). When it runs on an operation, it makes
  ;;               the thread known to Scheme, sets the current MLIR context to the context of the
  ;;               operation, and calls entry with the address of the operation. When entry returns 0
  ;;               the pass fails, and any other number is success.
  ;;               It does not make entry: define-pass makes that C function once, for the body, and
  ;;               every pass that (name) makes shares it.
  ;;               LEAK WARNING: nothing owns the pass until mlir::PassManager::addPass or
  ;;               mlir::OpPassManager::addPass takes it. Then the PassManager, made by
  ;;               with-PassManager, owns it. A pass that is made and never added leaks.
  ;;               This is the raw binding %crest::createSchemePass of (crest pass ffi), exported
  ;;               here without the %. define-pass calls it each time (name) is called; call it
  ;;               directly only to make a pass from a C function that is not made by define-pass.
  ;; @example
  ;;   (define-c-callable entry ((op uptr)) int 1)
  ;;   (mlir::PassManager::addPass pm (crest::createSchemePass "always-ok" entry))
  (define crest::createSchemePass %crest::createSchemePass)

  ) ;; end library (crest pass)
