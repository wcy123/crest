;; Bridges lib/Bindings/crest/SchemePass.cpp
(library (crest pass ffi)
  (export %crest::createSchemePass)
  (import (chezscheme)
          (crest support foreign))

  ;; %crest::createSchemePass: make a crest::SchemePass object that runs a body written in Scheme
  ;; (define-pass does it). (crest pass) re-exports %crest::createSchemePass as
  ;; crest::createSchemePass, and only (crest pass) uses the name with the %.
  ;;
  ;; Input
  ;;   name   (string)  the name of the pass: what getName returns
  ;;   entry  (uptr)    the address of the C function that define-pass made for the body, int (uptr op)
  ;;
  ;; Returns the address of a new crest::SchemePass object, as the address of an mlir::Pass object:
  ;; this is what PassManager::addPass takes.
  ;; LEAK WARNING: nothing owns the crest::SchemePass object until mlir::PassManager::addPass or
  ;; mlir::OpPassManager::addPass takes the crest::SchemePass object. Then the PassManager, made by
  ;; with-PassManager, owns the crest::SchemePass object. A crest::SchemePass object that is made
  ;; and never added leaks.
  ;;
  ;; The crest::SchemePass object runs on any mlir::Operation object: the PassManager that the
  ;; crest::SchemePass object is added to decides which (nest "toy.func" runs the pass on each
  ;; toy.func). When the crest::SchemePass object runs on an mlir::Operation object, it calls entry
  ;; with the address of that mlir::Operation object. 0 fails the pass, any other number is success.
  ;; An error of the body is a diagnostic in the context of that mlir::Operation object, and entry
  ;; returns 0 (see define-c-callable in (crest callback)).
  (define %crest::createSchemePass
    (crest-foreign-procedure "crest::createSchemePass" (string uptr) uptr))

  ) ;; end library (crest pass ffi)
