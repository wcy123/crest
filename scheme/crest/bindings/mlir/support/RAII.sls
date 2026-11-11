#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support RAII) — a generic way to free a resource when a block ends.
;;
;; Provides with-raii. It has no C++ counterpart: it is the plain Scheme version of a C++
;; destructor that runs at the end of a scope (std::unique_ptr, llvm::SaveAndRestore). The
;; macros of the form with-<C++ClassName> (CLAUDE.md, Rules 10, 12 and 18) are written on top of
;; it when their cleanup is a function call.
;;
;;===----------------------------------------------------------------------===;;
(library (mlir support RAII)
  (export with-raii)
  (import (rnrs)
          (only (chezscheme) void))

  ;; @brief with-raii — binds VARIABLE to the resource, runs BODY, then frees the resource.
  ;; The destructor runs when BODY returns, when it raises an error, and when it escapes through a
  ;; continuation (the macro uses dynamic-wind).
  ;; @param variable     identifier that names the resource inside BODY
  ;; @param constructor  expression that makes the resource; evaluated once, before BODY
  ;; @param destructor   procedure of one argument; called with the resource when BODY ends. If
  ;;                     the constructor raises an error, it is not called.
  ;; @param body         expressions evaluated with VARIABLE in scope; the value of the last one is
  ;;                     the value of the macro
  ;; @example
  ;;   (with-raii buffer (allocate 1024) free
  ;;     (use buffer))
  (define-syntax with-raii
    (syntax-rules ()
      [(_ variable constructor destructor body ...)
       (let ([variable constructor])
         (dynamic-wind
             void
             (lambda () body ...)
             (lambda () (destructor variable))))]))

  ) ;; end library (mlir support RAII)
