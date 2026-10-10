#!r6rs
(library (crest internal srcloc)
  (export %%bfp->line+col)
  (import (except (rnrs (6)) =)
          (only (chezscheme) make-hashtable string-hash guard)
          (rename (rime loop) (:with :rime-with)))

  ;; %%bfp->line+col : filename bfp → (values line col)  (both 1-indexed)
  ;;
  ;; Builds a sorted vector of line-start byte positions once per file and
  ;; resolves (filename, bfp) → (line, col) via binary search.
  ;; Falls back to (values 1 1) when the file cannot be read.
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
        (let loop ([lo 0] [hi (- (vector-length v) 1)])
          (if (= (+ lo 1) hi)
              (values (+ lo 1) (+ (- bfp (vector-ref v lo)) 1))
              (let ([mid (quotient (+ lo hi) 2)])
                (if (<= (vector-ref v mid) bfp)
                    (loop mid hi)
                    (loop lo mid))))))
      (lambda (filename bfp)
        (let ([v (get-line-starts filename)])
          (if v
              (line-starts->line+col v bfp)
              (values 1 1))))))

  ) ;; end library (crest internal srcloc)
