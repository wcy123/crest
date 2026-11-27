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
;; defines the procedure (name), which makes a new mlir::Pass object every time (name) is called
;; (PassManager::addPass consumes an mlir::Pass object). When the pass runs, op is the address of the
;; mlir::Operation object that the pass is anchored on (the PassManager that the mlir::Pass object is
;; added to decides which: nest "toy.func" runs the pass on each toy.func) and body runs;
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
  ;; A PassManager runs mlir::Pass objects. PassManager::addPass takes the address of an mlir::Pass
  ;; object, and owns that mlir::Pass object from then on, so each use needs a new mlir::Pass object.
  ;; A body written in Scheme is not an mlir::Pass object: crest::createSchemePass makes an mlir::Pass
  ;; object for the body. When MLIR runs that mlir::Pass object, the object calls a C function with
  ;; the address of the mlir::Operation object that the pass runs on, and the C function returns 1
  ;; (success) or 0 (failure). That C function is the body. By hand that is three things: the C
  ;; function with the right prototype, made once and kept for good; a procedure that makes a new
  ;; mlir::Pass object for that C function each time the procedure is called; and the name of the
  ;; pass as a string. define-pass makes all three from the body.
  ;;
  ;; Input
  ;;   name  the identifier to define, and the name of the pass: (name) makes an mlir::Pass object
  ;;         whose name is "name"
  ;;   op    the variable that the body sees: the address of the mlir::Operation object that the
  ;;         pass runs on
  ;;   body  what the pass does. #f fails the pass, any other value is success. The body is wrapped
  ;;         in (let () ...), so the body can begin with definitions.
  ;;
  ;; Why define-pass exists: the body of a pass is called from C++, and C++ and Scheme do not check each
  ;; other. A mistake at this boundary is not an error with a message: it crashes the process, or
  ;; leaks. define-pass does the delicate parts, so the end user writes only the body:
  ;;   - the prototype of the C function. C++ calls int (*)(uint64_t op), and nothing checks that the
  ;;     Scheme side declares the same types. A mismatch crashes. define-pass declares (op uptr) int.
  ;;   - the lifetime of the C function. The garbage collector moves Scheme objects, so the C function
  ;;     is made once and locked for good (define-c-callable). A C function that is not locked leaves
  ;;     C++ with a stale address.
  ;;   - the errors of the body. An error must not leave the C function: it would cross the C++ frames
  ;;     and skip their destructors. The C function catches the error, reports it as a diagnostic at
  ;;     the position of the body, and returns 0 (define-c-callable does it).
  ;;   - the value of the body. #f becomes 0 and any other value becomes 1, so the body cannot return
  ;;     a wrong C value.
  ;;   - the mlir::Pass object. PassManager::addPass consumes the mlir::Pass object, so (name) makes
  ;;     a new mlir::Pass object each time. All these mlir::Pass objects share the same C function.
  ;;   - the thread that calls the C function. MLIR may run the pass on a worker thread that Scheme
  ;;     does not know. Every C function that define-c-callable makes can be called from such a
  ;;     thread, and the SchemePass object makes the thread known once for the whole run.
  ;; The macro also defines the hidden name entry for the C function, once for each use of define-pass,
  ;; and takes the name of the pass from the identifier name.
  ;;
  ;; What stays with the end user: adding the mlir::Pass object to a PassManager (an mlir::Pass object
  ;; that is never added leaks), and the threads of the body. A pass nested on func.func can run on
  ;; several threads at the same time, so Scheme state that these runs share needs a mutex (see
  ;; "Threads" in docs/manual.md).
  ;;
  ;; crest::createSchemePass, the procedure that makes the mlir::Pass object, is described where this
  ;; library defines it, below.
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
  ;;   Used (every call of (tag-functions) makes a new mlir::Pass object):
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

  ;; @brief crest::createSchemePass — make an mlir::Pass object that runs the body of a define-pass.
  ;; @param name   the name of the pass, a string: what getName returns
  ;; @param entry  the address of the C function that define-pass made for the body, int (uptr op).
  ;;               The mlir::Pass object calls that C function with the address of the
  ;;               mlir::Operation object that the pass runs on
  ;; @return       the address of a new mlir::Pass object
  ;; @note         crest::createSchemePass makes a new SchemePass object (lib/Crest/SchemePass.cpp),
  ;;               an mlir::OperationPass that holds a copy of name and the pointer entry, and
  ;;               nothing else. getName returns name, and cloning the SchemePass object copies
  ;;               both.
  ;;               The SchemePass object runs on any mlir::Operation object: the PassManager that
  ;;               the SchemePass object is added to decides which (nest "toy.func" runs the pass on
  ;;               each toy.func). When the SchemePass object runs on an mlir::Operation object, it
  ;;               makes the thread known to Scheme, sets the current MLIR context to the context of
  ;;               that mlir::Operation object, and calls entry with the address of that
  ;;               mlir::Operation object. When entry returns 0 the pass fails, and any other number
  ;;               is success.
  ;;               crest::createSchemePass does not make entry: define-pass makes the C function once,
  ;;               for the body, and every mlir::Pass object that (name) makes shares that C function.
  ;;               LEAK WARNING: nothing owns the mlir::Pass object until
  ;;               mlir::PassManager::addPass or mlir::OpPassManager::addPass takes the mlir::Pass
  ;;               object. Then the PassManager, made by with-PassManager, owns the mlir::Pass
  ;;               object. An mlir::Pass object that is made and never added leaks.
  ;;               crest::createSchemePass is the raw binding %crest::createSchemePass of
  ;;               (crest pass ffi), exported here without the %. define-pass calls
  ;;               crest::createSchemePass each time (name) is called. Call crest::createSchemePass
  ;;               directly only to make an mlir::Pass object for a C function that define-pass did
  ;;               not make.
  ;; @example
  ;;   (define-c-callable entry ((op uptr)) int 1)
  ;;   (mlir::PassManager::addPass pm (crest::createSchemePass "always-ok" entry))
  (define crest::createSchemePass %crest::createSchemePass)

  ) ;; end library (crest pass)
