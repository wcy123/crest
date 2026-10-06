#!r6rs
(import (rnrs) (chezscheme))

;; Read entire file into a string
(define (file->string path)
  (call-with-input-file path (lambda (in) (get-string-all in))))

;; Split off leading lines that start with "#!"
;; Returns two values: (list of directive strings incl. newline), rest-string
(define (split-leading-bang-lines s)
  (let loop ((i 0) (dirs '()))
    (if (and (<= (+ i 1) (string-length s))
             (char=? (string-ref s i) #\#)
             (char=? (string-ref s (+ i 1)) #\!))
        (let* ((nl (let find-nl ((j i))
                     (if (or (= j (string-length s))
                             (char=? (string-ref s j) #\newline))
                         j
                         (find-nl (+ j 1)))))
               (line (substring s i (min (string-length s) (+ nl 1)))))
          (loop (+ nl 1) (cons line dirs)))
        (values (reverse dirs) (substring s i (string-length s))))))

;; Pretty-print all datums from in to out
(define (pp-port in out)
  (let loop ((x (read in)))
    (unless (eof-object? x)
      (pretty-print x out)
      (loop (read in)))))

;; Try to rename tmp -> path; if it fails (e.g., Windows open file), delete and retry
(define (atomic-replace tmp path)
  (let ((ok?
         (with-exception-handler
           (lambda (e) #f)
           (lambda ()
             (rename-file tmp path)
             #t))))
    (unless ok?
      (delete-file path)
      (rename-file tmp path))))

(define (format-file-in-place path)
  (let* ((content (file->string path))
         (tmp     (string-append path ".pp-temp")))
    (call-with-port
      (open-file-output-port tmp (file-options no-fail)
                             (buffer-mode block) (native-transcoder))
      (lambda (out)
        (call-with-values
            (lambda () (split-leading-bang-lines content))
          (lambda (directives rest)
            ;; Re-emit leading #! lines
            (for-each (lambda (d) (display d out)) directives)
            ;; Pretty-print the rest
            (let ((in (open-string-input-port rest)))
              (pp-port in out))))))
    (atomic-replace tmp path)))

(define (pp-stdin-to-stdout)
  (pp-port (current-input-port) (current-output-port)))

;; CLI:
;;   no args: read from stdin, write to stdout
;;   one arg: in-place format file
(let ((args (command-line-arguments)))
  (cond
    ((null? args) (pp-stdin-to-stdout))
    ((= (length args) 1) (format-file-in-place (car args)))
    (else (begin
            (display "usage: ppf-r6rs.sps [file]\n")
            (exit 1)))))
