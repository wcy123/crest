#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest support with) — with*, several with- forms without the indentation of each one.
;;
;; Provides with*. It has no C++ counterpart: it is to the with- macros (CLAUDE.md, Rules 10, 12 and
;; 18) what let* is to let.
;;
;;===----------------------------------------------------------------------===;;
(library (crest support with)
  (export with*)
  (import (rnrs))

  ;; @brief with* — nests the with- forms of its clauses, first clause outermost.
  ;; A clause is a with- form without its body. Each clause is in scope of the variables of the
  ;; clauses before it, and the cleanups run in the reverse order, also when the body raises an error.
  ;; The macro of a clause must take its body last, as every with- macro of CREST does.
  ;; @example
  ;;   (with* ((with-DialectRegistry registry ())
  ;;           (with-MLIRContext ctx (registry)))
  ;;     body ...)
  ;; is
  ;;   (with-DialectRegistry registry ()
  ;;     (with-MLIRContext ctx (registry)
  ;;       body ...))
  (define-syntax with*
    (syntax-rules ()
      [(_ () body ...)
       (let () body ...)]
      [(_ ((with-x clause ...) rest ...) body ...)
       (with-x clause ... (with* (rest ...) body ...))]))

  ) ;; end library (crest support with)
