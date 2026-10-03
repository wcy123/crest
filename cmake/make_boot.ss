;;===----------------------------------------------------------------------===;;
;;
;; cmake/make_boot.ss — Bundle compiled .so files into crest.boot
;;
;; Usage:
;;   scheme --script make_boot.ss <output-boot> <obj-dir>
;;
;; Walks obj-dir recursively to collect all .so files and calls
;; make-boot-file to bundle them into a single boot file.
;;
;;===----------------------------------------------------------------------===;;

(import (chezscheme))

(define output-boot (list-ref (command-line-arguments) 0))
(define obj-dir     (list-ref (command-line-arguments) 1))

(define (find-so-files dir)
  (fold-left
    (lambda (acc entry)
      (let ([path (string-append dir "/" entry)])
        (cond
          [(file-directory? path) (append acc (find-so-files path))]
          [(let ([n (string-length path)])
             (and (> n 3) (string=? (substring path (- n 3) n) ".so")))
           (append acc (list path))]
          [else acc])))
    '()
    (directory-list dir)))

(define so-files (find-so-files obj-dir))
(printf "Bundling ~a compiled libraries into ~a~n" (length so-files) output-boot)

(apply make-boot-file output-boot '("petite" "scheme") so-files)

(printf "Done.~n")
