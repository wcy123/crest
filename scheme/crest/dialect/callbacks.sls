#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest dialect callbacks) — the callbacks of a Scheme dialect as C functions.
;;
;;   (crest-dialect-callback-entries initialize get-dependent-dialects parse-attribute
;;     print-attribute parse-type print-type materialize-constant get-canonicalization-patterns
;;     verify-op-attr verify-region-arg-attr verify-region-result-attr)       a vector
;;
;; Each argument is the procedure the dialect wrote for that clause of define-dialect, or #f. The
;; answer is the vector that define-dialect binds to the dialect's name: for each slot, in the
;; same order, the entry point of a foreign-callable that calls the procedure (see (crest
;; callback)), or 0 for #f. C++ (lib/Crest/Dialect.cpp) keeps the addresses. define-dialect calls
;; this once, when the library of the dialect is loaded, so a context that loads the dialect
;; makes no callable of its own.
;;
;; The procedures keep the arguments they always had. What changes is how an answer is told to C:
;;   - a pointer that is #f is 0 (a parse that failed, no constant);
;;   - get-dependent-dialects answers a list of dialect names (strings);
;;   - a verifier says yes with any value but #f. An error that it raises does not leave the
;;     callable: its text goes to the diagnostic and the verifier fails.
;;
;;===----------------------------------------------------------------------===;;
(library (crest dialect callbacks)
  (export crest-dialect-callback-entries)
  (import (chezscheme)
          (crest callback)
          (crest dialect ffi))

  ;; The verdict of a verifier as C wants it: 1 or 0.
  (define (%%verdict thunk)
    (guard (c [#t (%crest::CrestDialect::reportFailure
                   (call-with-string-output-port
                    (lambda (port) (display-condition c port))))
                  0])
      (if (thunk) 1 0)))

  (define (crest-dialect-callback-entries initialize get-dependent-dialects parse-attribute
                                          print-attribute parse-type print-type
                                          materialize-constant get-canonicalization-patterns
                                          verify-op-attr verify-region-arg-attr
                                          verify-region-result-attr)
    (vector
     (if initialize
         (crest-callback-entry-point (uptr) void initialize)
         0)
     (if get-dependent-dialects
         (crest-callback-entry-point
          (uptr) void
          (lambda (dialect)
            (for-each (lambda (name) (%crest::CrestDialect::loadDependentDialect dialect name))
                      (get-dependent-dialects))))
         0)
     (if parse-attribute
         (crest-callback-entry-point
          (uptr uptr) uptr
          (lambda (parser type) (or (parse-attribute parser type) 0)))
         0)
     (if print-attribute
         (crest-callback-entry-point (uptr uptr) void print-attribute)
         0)
     (if parse-type
         (crest-callback-entry-point
          (uptr) uptr
          (lambda (parser) (or (parse-type parser) 0)))
         0)
     (if print-type
         (crest-callback-entry-point (uptr uptr) void print-type)
         0)
     (if materialize-constant
         (crest-callback-entry-point
          (uptr uptr uptr uptr) uptr
          (lambda (builder value type loc) (or (materialize-constant builder value type loc) 0)))
         0)
     (if get-canonicalization-patterns
         (crest-callback-entry-point (uptr) void get-canonicalization-patterns)
         0)
     (if verify-op-attr
         (crest-callback-entry-point
          (uptr uptr) int
          (lambda (op attr) (%%verdict (lambda () (verify-op-attr op attr)))))
         0)
     (if verify-region-arg-attr
         (crest-callback-entry-point
          (uptr unsigned-32 unsigned-32 uptr) int
          (lambda (op region-index arg-index attr)
            (%%verdict (lambda () (verify-region-arg-attr op region-index arg-index attr)))))
         0)
     (if verify-region-result-attr
         (crest-callback-entry-point
          (uptr unsigned-32 unsigned-32 uptr) int
          (lambda (op region-index result-index attr)
            (%%verdict (lambda ()
                         (verify-region-result-attr op region-index result-index attr)))))
         0)))

  ) ;; end library (crest dialect callbacks)
