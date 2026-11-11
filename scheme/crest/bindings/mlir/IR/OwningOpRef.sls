#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR OwningOpRef) — frees the operation that a parse returns.
;;
;; Mirrors mlir/IR/OwningOpRef.h.
;;
;; mlir::parseSourceFile answers the module as a plain address. Nothing owns it, so it is
;; never freed unless the program erases it. with-mlir::OwningOpRef<mlir::ModuleOp> does that.
;;
;;===----------------------------------------------------------------------===;;
(library (mlir IR OwningOpRef)
  (export with-mlir::OwningOpRef<mlir::ModuleOp>)
  (import (rnrs)
          (mlir IR Operation)
          (mlir support RAII))

  ;; The destructor of the module: 0 means that the parse failed and there is nothing to free.
  (define (%%erase-module module)
    (unless (eqv? module 0)
      (mlir::Operation::erase module)))

  ;; @brief with-mlir::OwningOpRef<mlir::ModuleOp> — binds MODULE to the module that CREATION
  ;; returns, runs BODY, then erases the module when BODY ends: by returning, by an error, or by an
  ;; escape.
  ;; @param module    identifier that names the module inside BODY
  ;; @param creation  the call that makes the module, usually (mlir::parseSourceFile ctx filename);
  ;;                  evaluated once, before BODY
  ;; @note  The C++ code that this replaces is
  ;;          mlir::OwningOpRef<mlir::ModuleOp> module = mlir::parseSourceFile<mlir::ModuleOp>(filename, config);
  ;; @note  MODULE is 0 when the file cannot be parsed (the parser has already printed why);
  ;;        nothing is erased then, so BODY must check for 0.
  ;; @note  Do not erase MODULE, or anything that owns it, inside BODY: it is erased once, at
  ;;        the end.
  ;; @example
  ;;   (with-mlir::OwningOpRef<mlir::ModuleOp> module (mlir::parseSourceFile ctx "input.mlir")
  ;;     (if (zero? module)
  ;;         (display "cannot parse\n")
  ;;         (display (mlir::Operation::print module))))
  (define-syntax with-mlir::OwningOpRef<mlir::ModuleOp>
    (syntax-rules ()
      [(_ module creation body ...)
       (with-raii module creation %%erase-module
                  body ...)]))

  ) ;; end library (mlir IR OwningOpRef)
