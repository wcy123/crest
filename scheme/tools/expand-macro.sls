;; expand-macro tool — pretty-prints macro expansions found in a Scheme source file.
;; Invoked via crest-opt by the tools/expand-macro shell script.
(library (tools expand-macro)
  (export run-pass)
  (import (chezscheme)
          (crest dialect))

  ;; Read all top-level s-expressions from a file.
  (define (%%read-all-forms file)
    (with-input-from-file file
      (lambda ()
        (let loop ([acc '()])
          (let ([form (read)])
            (if (eof-object? form)
                (reverse acc)
                (loop (cons form acc))))))))

  ;; Recursively walk an s-expression and collect all (name ...) sub-forms.
  (define (%%find-forms name form)
    (cond
     [(not (pair? form)) '()]
     [(eq? (car form) name) (list form)]
     [else (apply append (map (lambda (f) (%%find-forms name f)) form))]))

  ;; Seed the interaction environment with the macros we need to expand.
  (define %%env-ready #f)
  (define (%%ensure-env)
    (unless %%env-ready
      (eval '(import (crest dialect)) (interaction-environment))
      (set! %%env-ready #t)))

  (define (%%expand form)
    (%%ensure-env)
    (eval `(expand ',form) (interaction-environment)))

  ;; Post-process the pretty-printed string for a cleaner surface view.
  ;; Drops $invoke-library lines and strips #N% primitive prefixes.
  (define (%%surface-str str)

    ;; Split string on newline.
    (define (%%split-lines s)
      (let loop ([i 0] [start 0] [acc '()])
        (cond
         [(= i (string-length s))
          (reverse (cons (substring s start i) acc))]
         [(char=? (string-ref s i) #\newline)
          (loop (+ i 1) (+ i 1) (cons (substring s start i) acc))]
         [else
          (loop (+ i 1) start acc)])))

    ;; Find first occurrence of sub in s from position from; return index or #f.
    (define (%%search sub s from)
      (let ([ns (string-length s)] [nsub (string-length sub)])
        (let loop ([i from])
          (cond
           [(> (+ i nsub) ns) #f]
           [(string=? (substring s i (+ i nsub)) sub) i]
           [else (loop (+ i 1))]))))

    ;; Remove lines containing $invoke-library.
    (define (%%drop-invoke lines)
      (filter (lambda (line) (not (%%search "$invoke-library" line 0))) lines))

    ;; Join lines with newline separator.
    (define (%%join lines)
      (let loop ([ls lines] [acc ""])
        (if (null? ls) acc
            (loop (cdr ls)
                  (if (string=? acc "") (car ls)
                      (string-append acc "\n" (car ls)))))))

    ;; Strip #N% primitive prefixes (e.g. #2%string=? → string=?).
    (define (%%strip s)
      (let loop ([i 0] [out ""])
        (if (= i (string-length s))
            out
            (let ([ch (string-ref s i)])
              (if (and (char=? ch #\#)
                       (< (+ i 1) (string-length s))
                       (char-numeric? (string-ref s (+ i 1))))
                  (let scan ([j (+ i 1)])
                    (cond
                     [(>= j (string-length s))
                      (loop (+ i 1) (string-append out "#"))]
                     [(char-numeric? (string-ref s j))
                      (scan (+ j 1))]
                     [(char=? (string-ref s j) #\%)
                      (loop (+ j 1) out)]
                     [else
                      (loop (+ i 1) (string-append out "#"))]))
                  (loop (+ i 1) (string-append out (string ch))))))))

    (%%strip (%%join (%%drop-invoke (%%split-lines str)))))

  (define (run-pass _op)
    (let* ([name    (string->symbol
                     (or (getenv "EXPAND_MACRO_NAME") "define-dialect"))]
           [file    (or (getenv "EXPAND_MACRO_FILE")
                        (error 'expand-macro "EXPAND_MACRO_FILE not set"))]
           [surface (getenv "EXPAND_MACRO_SURFACE")]
           [forms   (%%read-all-forms file)]
           [targets (apply append (map (lambda (f) (%%find-forms name f)) forms))])
      (if (null? targets)
          (display (string-append "No (" (symbol->string name)
                                  " ...) found in " file "\n"))
          (parameterize ([print-gensym #f])
            (for-each
             (lambda (form)
               (display (string-append ";; (" (symbol->string name) " ...)\n"))
               (let* ([expanded (syntax->datum (%%expand form))]
                      [printed  (with-output-to-string (lambda () (pretty-print expanded)))])
                 (display (if surface (%%surface-str printed) printed)))
               (newline))
             targets)))))
  )
