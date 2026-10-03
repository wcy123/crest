;;===----------------------------------------------------------------------===;;
;;
;; cmake/compile_scheme_libs.ss — Compile all CREST Scheme libraries (single process)
;;
;; Usage:
;;   scheme --script compile_scheme_libs.ss
;;          <order-file> <scheme-src> <rime-src> <output-boot>
;;
;; Copies .sls source files to local /tmp, compiles entirely on local disk
;; (no NFS writes), then calls make-boot-file from the local .so files.
;; This completely bypasses NFS attribute cache issues.
;;
;;===----------------------------------------------------------------------===;;

(import (chezscheme))

(define args        (command-line-arguments))
(define order-file  (list-ref args 0))
(define scheme-src  (list-ref args 1))  ; NFS source dir (read-only)
(define rime-src    (list-ref args 2))  ; rime NFS dir (read-only)
(define output-boot (list-ref args 3))

;; ─── Local workspace ──────────────────────────────────────────────────────────
(define local-ws (string-append "/tmp/crest-compile-" (number->string (random 999999))))
(define local-src (string-append local-ws "/src"))
(define local-obj (string-append local-ws "/obj"))
(system (string-append "mkdir -p " local-src " " local-obj))

;; ─── Copy .sls sources to local disk ─────────────────────────────────────────
;; Use rsync to exclude .git (pack files may be read-only and cause cp errors).
(system (string-append "rsync -a --exclude='.git' " scheme-src "/ " local-src "/"))
(system (string-append "rsync -a --exclude='.git' " rime-src "/ " local-ws "/rime/"))

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

;; ─── Library search / output paths (set BEFORE any compilation) ─────────────
;; Source: local-src (crest .sls), local-ws/rime (rime .sls)
;; Object: local-obj (compiled .so — local disk, no NFS issues)
(library-directories
  (list (cons local-src local-obj)
        (cons (string-append local-ws "/rime") local-obj)))

(optimize-level 2)
(generate-wpo-files #f)

;; ─── Compile rime/loop (needed at expand and runtime by crest/ddr/*) ─────────
;; compile-imported-libraries #t causes all rime sub-dependencies to be
;; compiled automatically when rime/loop.sls is compiled.
(compile-imported-libraries #t)
(compile-library (string-append local-ws "/rime/rime/loop.sls"))
(compile-imported-libraries #f)

(printf "Compiling ~a CREST Scheme libraries (local /tmp)~n" (length libraries))

;; ─── Compile from local source ───────────────────────────────────────────────
;; Use absolute paths so compile-library matches against library-directories.
(for-each
  (lambda (sls)
    (let* ([base      (substring sls 0 (- (string-length sls) 4))]
           [abs-src   (string-append local-src "/" sls)]
           [dest-dir  (string-append local-obj "/" (let loop ([i (- (string-length base) 1)])
                                                    (if (or (= i 0) (char=? (string-ref base i) #\/))
                                                        (if (= i 0) base (substring base 0 i))
                                                        (loop (- i 1)))))])
      (printf "  (~a)~n" base)
      (system (string-append "mkdir -p " dest-dir))
      (compile-library abs-src)))
  libraries)

;; ─── Bundle into crest.boot ───────────────────────────────────────────────────
;; Collect all compiled .so files: rime first (they must come before crest libs
;; that depend on them), then crest libs in topological order.
(define (find-so-files dir)
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
    (directory-list dir)))

;; Rime .so files land in TWO places:
;;   - loop.so itself: in local-ws/rime/rime/ (compiled via absolute path, no redirect)
;;   - all sub-libraries: in local-obj/ (compiled transitively via library-directories redirect)
;; Crest .so files: in local-src/ (absolute path, no redirect)
(define rime-so-files (append (find-so-files (string-append local-ws "/rime"))
                               (find-so-files local-obj)))
(define crest-so-files
  (map (lambda (sls)
         (string-append local-src "/" (substring sls 0 (- (string-length sls) 4)) ".so"))
       libraries))
(define so-files (append rime-so-files crest-so-files))

(printf "Creating boot file: ~a~n" output-boot)
(apply make-boot-file output-boot '("petite" "scheme") so-files)

;; ─── Cleanup ──────────────────────────────────────────────────────────────────
(system (string-append "rm -rf " local-ws))
(printf "Done.~n")
