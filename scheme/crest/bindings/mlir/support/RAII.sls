#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support RAII) — Generic RAII helper for Scheme-managed C++ resources.
;;
;; Provides with-raii, the primitive underlying all with-<C++ClassName> macros.
;; Has no C++ counterpart; the pattern is analogous to std::unique_ptr or
;; llvm::SaveAndRestore.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support RAII)
  (export with-raii)
  (import (rnrs)
          (only (chezscheme) void))

  ;; @brief with-raii — single-resource RAII.
  ;; Binds VAR to (CTOR), evaluates BODY forms, then calls (DTOR VAR) on exit
  ;; whether BODY returns normally, raises an exception, or escapes via a
  ;; continuation.  Uses dynamic-wind so cleanup always runs.
  ;;
  ;; @param var   identifier bound to the resource inside BODY
  ;; @param ctor  expression that creates the resource (evaluated once)
  ;; @param dtor  procedure called on VAR when BODY exits
  ;; @param body  one or more expressions evaluated with VAR in scope
  ;;
  ;; Example:
  ;;   (with-raii (buf (malloc 1024) free)
  ;;     (use buf))
  (define-syntax with-raii
    (syntax-rules ()
      [(_ (var ctor dtor) body ...)
       (let ([var ctor])
         (dynamic-wind void
             (lambda () body ...)
             (lambda () (dtor var))))]))

  ) ;; end library (mlir support RAII)
