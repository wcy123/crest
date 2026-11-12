#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support srcloc) — Source locations of Scheme code, read from syntax objects when a macro
;; expands: the DSL macros (pattern-dsl, dialect) and (crest callback) use them.
;;
;; %%bfp->line+col : filename bfp → (values line col)  (both 1-indexed)
;;   Resolves a byte-file-position to (line, col) via binary search over a
;;   cached vector of line-start offsets.  Falls back to (values #f #f) on
;;   I/O error.  Cache is module-level — shared across all callers and all
;;   macro expansions in the session, maximising hit rate.
;;
;; syntax->file+line+col : stx → (list file line col) | #f
;;   Extracts source annotation from a syntax object and resolves
;;   bfp → (line, col).  Returns #f when unavailable.
;;   Use with apply: (apply (lambda (f l c) ...) loc)
;;
;; syntax->first-file+line+col : stx → (list file line col) | #f
;;   The same for a form that a macro built from a template, such as (lambda formals body ...) made by
;;   the DSL: the form and its keyword are at the template, in a library of CREST, and only the formals
;;   and the body are the user's. The result is the position of the first part of the form that is not
;;   in a file of CREST's own libraries (the directory scheme/), searched depth first, or the first
;;   position when there is none.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support srcloc)
  (export syntax->file+line+col
          syntax->first-file+line+col)
  (import (rnrs)
          (only (chezscheme) make-hashtable string-hash guard quotient syntax->list find
                syntax->annotation annotation? annotation-source
                source-object? source-object-sfd source-object-bfp
                source-file-descriptor-path)
          (rime loop))

  ;;-------------------------------------------------------------------
  ;; %%bfp->line+col
  ;;-------------------------------------------------------------------
  ;;
  ;; Module-level cache: created once when this library is instantiated.
  ;; All callers at the same phase share the same hashtable.
  ;;
  (define %%bfp->line+col
    (let ([cache (make-hashtable string-hash string=?)])
      (define (get-line-starts filename)
        (or (hashtable-ref cache filename #f)
            (let ([v (compute-line-starts filename)])
              (when v (hashtable-set! cache filename v))
              v)))
      (define (compute-line-starts filename)
        (guard (e [#t #f])
          (call-with-port
              (transcoded-port (open-file-input-port filename)
                               (make-transcoder (utf-8-codec) (eol-style none)))
            (lambda (p)
              (loop :for pos :from 0
                    :with ch := (read-char p)
                    :break :if (eof-object? ch)
                    :if (char=? ch #\newline)
                    :collect (+ pos 1)
                    :finally (list->vector (cons 0 (append :return-value (list (- pos 1))))))))))
      ;; Binary search: largest lo s.t. v[lo] <= bfp < v[lo+1].
      (define (line-starts->line+col v bfp)
        (let lp ([lo 0] [hi (- (vector-length v) 1)])
          (if (= (+ lo 1) hi)
              (values (+ lo 1) (+ (- bfp (vector-ref v lo)) 1))
              (let ([mid (quotient (+ lo hi) 2)])
                (if (<= (vector-ref v mid) bfp)
                    (lp mid hi)
                    (lp lo mid))))))
      (lambda (filename bfp)
        (let ([v (get-line-starts filename)])
          (if v
              (line-starts->line+col v bfp)
              (values #f #f))))))

  ;;-------------------------------------------------------------------
  ;; syntax->file+line+col
  ;;-------------------------------------------------------------------
  (define (syntax->file+line+col stx)
    (let* ([ann (syntax->annotation stx)]
           [src (and (annotation? ann) (annotation-source ann))]
           [sfd (and (source-object? src) (source-object-sfd src))]
           [bfp (and sfd (source-object-bfp src))])
      (if sfd
          (let ([file (source-file-descriptor-path sfd)])
            (let-values ([(line col) (%%bfp->line+col file bfp)])
              (and line (list file line col))))
          #f)))

  ;; The directory of CREST's own libraries, "<...>/scheme/": this file is
  ;; <...>/scheme/crest/bindings/mlir/support/srcloc.sls. A position in a file below it is the code
  ;; of a macro of CREST (the template of a DSL), not the code of the user.
  (define %%crest-library-root
    (let* ([here (syntax->file+line+col #'here)]
           [path (and here (car here))]
           [tail "crest/bindings/mlir/support/srcloc.sls"])
      (and path
           (> (string-length path) (string-length tail))
           (string=? (substring path (- (string-length path) (string-length tail)) (string-length path))
                     tail)
           (substring path 0 (- (string-length path) (string-length tail))))))

  (define (%%crest-library? path)
    (and %%crest-library-root
         (>= (string-length path) (string-length %%crest-library-root))
         (string=? (substring path 0 (string-length %%crest-library-root)) %%crest-library-root)))

  (define (syntax->first-file+line+col stx)
    ;; All the positions of the form and of its parts, depth first.
    (define (positions form)
      (let ([own (syntax->file+line+col form)]
            [items (guard (e [#t #f]) (syntax->list form))])
        (append (if own (list own) '())
                (if items (apply append (map positions items)) '()))))
    (let ([all (positions stx)])
      (and (pair? all)
           (or (find (lambda (position) (not (%%crest-library? (car position)))) all)
               (car all)))))

  ) ;; end library (mlir support srcloc)
