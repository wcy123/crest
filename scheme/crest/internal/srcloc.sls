#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest internal srcloc) — Source location utilities shared by rewrite.sls
;; and codegen.sls.
;;
;; %%bfp->line+col : filename bfp → (values line col)  (both 1-indexed)
;;   Resolves a byte-file-position to (line, col) via binary search over a
;;   cached vector of line-start offsets.  Falls back to (values #f #f) on
;;   I/O error.  Cache is module-level — shared across all callers and all
;;   macro expansions in the session, maximising hit rate.
;;
;; %%syntax->loc-string : stx → string
;;   Extracts the source annotation from a syntax object and returns a
;;   "file:line:col" string, or "unknown" when no annotation is available.
;;
;;===----------------------------------------------------------------------===;;

(library (crest internal srcloc)
  (export %%bfp->line+col %%syntax->loc-string)
  (import (rnrs)
          (only (chezscheme) make-hashtable string-hash guard quotient
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
  ;; %%syntax->loc-string
  ;;-------------------------------------------------------------------
  (define (%%syntax->loc-string stx)
    (let* ([ann (syntax->annotation stx)]
           [src (and (annotation? ann) (annotation-source ann))]
           [sfd (and (source-object? src) (source-object-sfd src))]
           [bfp (and sfd (source-object-bfp src))])
      (if sfd
          (let ([file (source-file-descriptor-path sfd)])
            (let-values ([(line col) (%%bfp->line+col file bfp)])
              (if line
                  (string-append file ":" (number->string line) ":" (number->string col))
                  file)))
          "unknown")))

  ) ;; end library (crest internal srcloc)
