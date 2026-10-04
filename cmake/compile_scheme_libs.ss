;;===----------------------------------------------------------------------===;;
;;
;; cmake/compile_scheme_libs.ss — Compile all CREST Scheme libraries
;;
;; Usage:
;;   scheme --script compile_scheme_libs.ss
;;          <scheme-src> <rime-src> <obj-dir> <output-boot>
;;
;; library-directories (source . object) pairs are the key:
;;   - source-dir: where Chez finds .sls source files (read-only)
;;   - object-dir: where Chez writes compiled .so files (build tree)
;;
;; With compile-imported-libraries #t, compiling the root library triggers
;; recursive compilation of ALL transitive dependencies in topological order.
;; No manual ordering, no scanner, no order file needed.
;;
;; The source tree is NEVER written to — all output goes to obj-dir.
;;
;;===----------------------------------------------------------------------===;;

(import (chezscheme))

(define args        (command-line-arguments))
(define scheme-src  (list-ref args 0))
(define rime-src    (list-ref args 1))
(define obj-dir     (list-ref args 2))
(define output-boot (list-ref args 3))

;; ─── Library search / output paths ───────────────────────────────────────────
;; (source-dir . object-dir) pairs: Chez reads .sls from source-dir and
;; writes compiled .so into object-dir.  This is the critical setting that
;; keeps all compiled artifacts in the build tree.
(library-directories
  (list (cons scheme-src obj-dir)
        (cons rime-src   obj-dir)))

;; ─── Compilation options ──────────────────────────────────────────────────────
(optimize-level 2)
(generate-wpo-files #f)

;; ─── Compile everything via the root library ──────────────────────────────────
;; compile-imported-libraries #t: when compiling a library, Chez automatically
;; compiles any uncompiled import first (topological order, handled by Chez).
;; All transitive dependencies flow through library-directories → obj-dir.
(compile-imported-libraries #t)

;; Pre-create destination directory for the root library output.
;; Transitive dependency directories are created by Chez via library-directories.
;; cmake -E make_directory already created obj-dir; we only need one more level.
(guard (e [else #f]) (mkdir (string-append obj-dir "/passes")))

;; Compile the root library. Chez recursively compiles every import
;; (mlir core ir, crest ddr, mlir hip fusion, rime loop, ...) first,
;; each written to obj-dir via the (source . object) pair.
(compile-file (string-append scheme-src "/passes/hip-fusion.sls")
              (string-append obj-dir   "/passes/hip-fusion.so"))

;; ─── Bundle into crest.boot ───────────────────────────────────────────────────
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
