#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest pass) — crest::createSchemePass: make a crest::SchemePass object that runs a C function.
;;
;; Bridges lib/Bindings/crest/SchemePass.cpp. The DSL that uses it is define-pass, in
;; (crest define-pass).
;;
;;===----------------------------------------------------------------------===;;

(library (crest pass)
  (export crest::createSchemePass)
  (import (rnrs)
          (crest pass ffi))

  ;; @brief crest::createSchemePass — make a crest::SchemePass object that runs the body of a
  ;;        define-pass.
  ;; @param name   the name of the pass, a string: what getName returns
  ;; @param entry  the address of the C function that define-pass made for the body, int (uptr op).
  ;;               The crest::SchemePass object calls that C function with the address of the
  ;;               mlir::Operation object that the pass runs on
  ;; @return       the address of a new crest::SchemePass object, as the address of an mlir::Pass
  ;;               object: this is what PassManager::addPass takes
  ;; @note         crest::SchemePass derives from mlir::OperationPass<>, and
  ;;               mlir::OperationPass<> derives from mlir::Pass:
  ;;
  ;;                   mlir::Pass               (mlir/Pass/Pass.h)
  ;;                       ^
  ;;                       | derives from
  ;;                   mlir::OperationPass<>    (mlir/Pass/Pass.h)
  ;;                       ^
  ;;                       | derives from
  ;;                   crest::SchemePass        (lib/Bindings/crest/SchemePass.cpp)
  ;;
  ;;               A crest::SchemePass object holds a copy of name and the pointer entry, and
  ;;               nothing else. getName returns name, and cloning the crest::SchemePass object
  ;;               copies both.
  ;;               The crest::SchemePass object runs on any mlir::Operation object: the PassManager
  ;;               that the crest::SchemePass object is added to decides which (nest "toy.func" runs
  ;;               the pass on each toy.func). When the crest::SchemePass object runs on an
  ;;               mlir::Operation object, it makes the thread known to Scheme, sets the current MLIR
  ;;               context to the context of that mlir::Operation object, and calls entry with the
  ;;               address of that mlir::Operation object. When entry returns 0 the pass fails, and
  ;;               any other number is success.
  ;;               crest::createSchemePass does not make entry: define-pass makes the C function
  ;;               once, for the body, and every crest::SchemePass object that (name) makes shares
  ;;               that C function.
  ;;               LEAK WARNING: nothing owns the crest::SchemePass object until
  ;;               mlir::PassManager::addPass or mlir::OpPassManager::addPass takes the
  ;;               crest::SchemePass object. Then the PassManager, made by with-PassManager, owns the
  ;;               crest::SchemePass object. A crest::SchemePass object that is made and never added
  ;;               leaks.
  ;;               crest::createSchemePass is the raw binding %crest::createSchemePass of
  ;;               (crest pass ffi), exported here without the %. define-pass calls
  ;;               crest::createSchemePass each time (name) is called. Call crest::createSchemePass
  ;;               directly only to make a crest::SchemePass object for a C function that
  ;;               define-pass did not make.
  ;; @example
  ;;   (define-c-callable entry ((op uptr)) int 1)
  ;;   (mlir::PassManager::addPass pm (crest::createSchemePass "always-ok" entry))
  (define crest::createSchemePass %crest::createSchemePass)

  ) ;; end library (crest pass)
