#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR OwningOpRef) — frees the operation that a call returns, such as a parsed module.
;;
;; Mirrors mlir/IR/OwningOpRef.h.
;;
;; mlir::parseSourceFile answers the module as a plain address. Nothing owns it, so it is
;; never freed unless the program erases it. with-mlir::OwningOpRef does that.
;;
;;===----------------------------------------------------------------------===;;
(library (mlir IR OwningOpRef)
  (export with-mlir::OwningOpRef)
  (import (rnrs)
          (mlir IR Operation)
          (crest support RAII))

  ;; @brief with-mlir::OwningOpRef — binds OP to the operation that CREATION returns, runs BODY,
  ;; then erases the operation when BODY ends: by returning, by an error, or by an escape.
  ;; @param op        identifier that names the operation inside BODY
  ;; @param creation  the call that makes the operation, usually (mlir::parseSourceFile ctx filename);
  ;;                  evaluated once, before BODY
  ;; @note  It works for any operation, as mlir::OwningOpRef<OpTy> does in C++: the C++ code that
  ;;        this replaces is
  ;;          mlir::OwningOpRef<mlir::ModuleOp> module = mlir::parseSourceFile<mlir::ModuleOp>(filename, config);
  ;; @note  OP is 0 when the file cannot be parsed (the parser has already printed why). Erasing 0
  ;;        does nothing, so BODY only has to check for 0 if it uses the operation.
  ;; @note  CREATION must return an operation that nothing else owns: a parse result, or an
  ;;        operation that you made and did not insert into another one. Do not erase OP, or
  ;;        anything that owns it, inside BODY: it is erased once, at the end.
  ;; @example
  ;;   (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx "input.mlir")
  ;;     (if (zero? module)
  ;;         (display "cannot parse\n")
  ;;         (display (mlir::Operation::print module))))
  (define-syntax with-mlir::OwningOpRef
    (syntax-rules ()
      [(_ op creation body ...)
       (with-raii op creation mlir::Operation::erase
         body ...)]))

  ) ;; end library (mlir IR OwningOpRef)
