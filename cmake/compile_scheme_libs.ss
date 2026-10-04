;;===----------------------------------------------------------------------===;;
;;
;; cmake/compile_scheme_libs.ss — Compile CREST Scheme libraries into a boot file
;;
;; Usage:
;;   scheme --script compile_scheme_libs.ss
;;          <obj-dir> <output-boot> <n-source-dirs>
;;          <source-dir-1> ... <source-dir-n>
;;          <root-sls-1>  ... <root-sls-m>
;;
;;   obj-dir:       build-tree directory for compiled .so output
;;   output-boot:   destination for the resulting .boot file
;;   n-source-dirs: number of source-dir arguments that follow
;;   source-dirs:   absolute paths to .sls source trees (read-only)
;;   root-sls:      absolute paths to root libraries; each triggers recursive
;;                  compilation of all transitive imports via
;;                  compile-imported-libraries #t
;;
;; library-directories (source . object) pairs redirect compiled output
;; to obj-dir — the source trees are NEVER written to.
;;
;;===----------------------------------------------------------------------===;;

(import (chezscheme))

(define args        (command-line-arguments))
(define obj-dir     (list-ref args 0))
(define output-boot (list-ref args 1))
(define n-srcs      (string->number (list-ref args 2)))
(define source-dirs (list-head (list-tail args 3) n-srcs))
(define root-libs   (list-tail args (+ 3 n-srcs)))

;; ─── Library search / output paths ───────────────────────────────────────────
;; Each (source-dir . obj-dir) pair tells Chez: find .sls in source-dir,
;; write compiled .so to obj-dir.  All sources are read-only.
(library-directories
  (map (lambda (src) (cons src obj-dir)) source-dirs))

;; ─── Compilation options ──────────────────────────────────────────────────────
(optimize-level 2)
(generate-wpo-files #f)

;; ─── Compile each root library ────────────────────────────────────────────────
;; compile-imported-libraries #t: Chez automatically compiles any uncompiled
;; import before the importing library (topological order, no manual sorting).
;; All transitive dependencies flow through library-directories → obj-dir.
(compile-imported-libraries #t)

(for-each
  (lambda (root-sls)
    ;; Derive the output .so path: same relative structure as source, in obj-dir.
    ;; The source dir prefix is stripped to get the relative path.
    (let* ([rel  (let find ([srcs source-dirs])
                   (if (null? srcs)
                       (error 'compile-scheme-libs "root not under any source-dir" root-sls)
                       (let* ([src (car srcs)]
                              [prefix (string-append src "/")])
                         (if (and (> (string-length root-sls) (string-length prefix))
                                  (string=? (substring root-sls 0 (string-length prefix)) prefix))
                             (substring root-sls (string-length prefix) (string-length root-sls))
                             (find (cdr srcs))))))]
           [dest (string-append obj-dir "/"
                                (substring rel 0 (- (string-length rel) 4))
                                ".so")]
           [ddir (let loop ([i (- (string-length dest) 1)])
                   (if (char=? (string-ref dest i) #\/)
                       (substring dest 0 i)
                       (loop (- i 1))))])
      (guard (e [else #f]) (mkdir ddir))
      (printf "Compiling root: ~a~n" rel)
      (compile-file root-sls dest)))
  root-libs)

;; ─── Bundle all compiled .so files into crest.boot ───────────────────────────
(define (find-so-files dir)
  (guard (e [else '()])
    (fold-left
      (lambda (acc f)
        (let ([path (string-append dir "/" f)])
          (cond
            [(file-directory? path) (append acc (find-so-files path))]
            [(let ([n (string-length f)])
               (and (> n 3) (string=? (substring f (- n 3) n) ".so")))
             (append acc (list path))]
            [else acc])))
      '()
      (directory-list dir))))

(define so-files (find-so-files obj-dir))
(printf "Creating boot file: ~a (~a libraries)~n" output-boot (length so-files))
(apply make-boot-file output-boot '("petite" "scheme") so-files)
(printf "Done.~n")
