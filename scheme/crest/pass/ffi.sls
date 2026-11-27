;; Bridges lib/Crest/SchemePass.cpp
(library (crest pass ffi)
  (export %crest::createSchemePass)
  (import (chezscheme)
          (crest support foreign))

  ;; %crest::createSchemePass: make a pass that runs a body written in Scheme (define-pass does it).
  ;;
  ;; Input
  ;;   name   (string)  the name of the pass: what getName returns
  ;;   entry  (uptr)    the address of the C function that define-pass made for the body, int (uptr op)
  ;;
  ;; Returns the address of a new mlir::Pass.
  ;; LEAK WARNING: nothing owns the pass until mlir::PassManager::addPass or
  ;; mlir::OpPassManager::addPass takes it. Then the PassManager, made by with-PassManager, owns it.
  ;; A pass that is made and never added leaks.
  ;;
  ;; The pass runs on any operation: the PassManager it is added to decides which (nest "toy.func"
  ;; runs it on each toy.func). When it runs, it calls entry with the address of the operation. 0
  ;; fails the pass, any other number is success. An error of the body is a diagnostic in the context
  ;; of the operation, and entry returns 0 (see define-c-callable in (crest callback)).
  (define %crest::createSchemePass
    (crest-foreign-procedure "crest::createSchemePass" (string uptr) uptr))

  ) ;; end library (crest pass ffi)
