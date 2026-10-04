;;===----------------------------------------------------------------------===;;
;;
;; cmake/compile_scheme_libs.ss — Compile all CREST Scheme libraries
;;
;; Usage:
;;   scheme --script compile_scheme_libs.ss
;;          <order-file> <scheme-src> <rime-src> <obj-dir> <output-boot>
;;
;; compile-file is used with an explicit output path so compiled .so files
;; go directly into <obj-dir> (inside the build tree). The NFS source tree
;; is NEVER written to — no copying, no cleanup, portable across platforms.
;;
;;===----------------------------------------------------------------------===;;

(import (chezscheme))

(define args        (command-line-arguments))
(define order-file  (list-ref args 0))
(define scheme-src  (list-ref args 1))  ; absolute path, read-only source
(define rime-src    (list-ref args 2))  ; absolute path, read-only source
(define obj-dir     (list-ref args 3))  ; absolute path, build-tree output
(define output-boot (list-ref args 4))

;; ─── Library search paths ─────────────────────────────────────────────────────
;; Sources are read from scheme-src / rime-src (never written).
;; Compiled imports are found in obj-dir (previously compiled libraries).
(library-directories
  (list (cons scheme-src obj-dir)
        (cons rime-src   obj-dir)))

;; ─── Read topologically-sorted library list ───────────────────────────────────
(define libraries
  (let ([p (open-input-file order-file)])
    (let loop ([libs '()])
      (let ([line (get-line p)])
        (if (eof-object? line)
            (begin (close-input-port p) (reverse libs))
            (if (or (string=? line "") (char=? (string-ref line 0) #\#))
                (loop libs)
                (loop (cons line libs))))))))

;; ─── Compilation options ──────────────────────────────────────────────────────
(optimize-level 2)
(generate-wpo-files #f)

;; ─── Compile rime/loop and all its sub-dependencies ──────────────────────────
;; compile-imported-libraries #t causes Chez to compile all transitive
;; imports of rime/loop into obj-dir (via the library-directories redirect).
;; Pre-create obj-dir/rime so Chez can write rime/loop.so there.
(system (string-append "mkdir -p " obj-dir "/rime"))
(compile-imported-libraries #t)
(compile-file (string-append rime-src "/rime/loop.sls")
              (string-append obj-dir "/rime/loop.so"))
(compile-imported-libraries #f)

;; ─── Compile each CREST library using compile-file with explicit output ────────
;; compile-file <src> <dest> reads from NFS source and writes .so directly
;; to obj-dir — no write ever touches the source tree.
(printf "Compiling ~a CREST Scheme libraries~n" (length libraries))

(define (sls->so sls)
  (string-append (substring sls 0 (- (string-length sls) 4)) ".so"))

(for-each
  (lambda (sls)
    (let* ([src  (string-append scheme-src "/" sls)]
           [dest (string-append obj-dir "/" (sls->so sls))]
           [ddir (let loop ([i (- (string-length dest) 1)])
                   (if (char=? (string-ref dest i) #\/)
                       (substring dest 0 i)
                       (loop (- i 1))))])
      (printf "  (~a)~n" (substring sls 0 (- (string-length sls) 4)))
      (system (string-append "mkdir -p " ddir))
      (compile-file src dest)))
  libraries)

;; ─── Collect .so files and bundle into crest.boot ─────────────────────────────
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
