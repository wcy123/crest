;;===----------------------------------------------------------------------===;;
;;
;; cmake/compile_scheme_libs.ss — Compile all CREST Scheme libraries
;;
;; Usage (WORKING_DIRECTORY must be CMAKE_CURRENT_BINARY_DIR/scheme-compile):
;;   scheme --script compile_scheme_libs.ss <order-file> <scheme-src> <rime-src> <output-boot>
;;
;; WORKING_DIRECTORY is the compile workspace inside the build tree.
;; All rsync destinations and compile-library outputs are relative to CWD,
;; so compiled artifacts NEVER touch the source tree — no pollution, no cleanup.
;;
;;===----------------------------------------------------------------------===;;

(import (chezscheme))

(define args        (command-line-arguments))
(define order-file  (list-ref args 0))
(define scheme-src  (list-ref args 1))  ; absolute path, read-only
(define rime-src    (list-ref args 2))  ; absolute path, read-only
(define output-boot (list-ref args 3))

;; ─── Sync sources into CWD (build tree) ──────────────────────────────────────
;; rsync into relative subdirs of CWD (= CMAKE_CURRENT_BINARY_DIR/scheme-compile).
;; --exclude='*.so/wpo' ensures no stale compiled artifacts are brought in.
(system (string-append "rsync -a --delete --exclude='.git' --exclude='*.so' --exclude='*.wpo' "
                       scheme-src "/ src/"))
(system (string-append "rsync -a --delete --exclude='.git' --exclude='*.so' --exclude='*.wpo' "
                       rime-src "/ rime/"))
(system "mkdir -p obj")

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

;; ─── Library search / output paths ───────────────────────────────────────────
;; Relative (source . object) pairs inside CWD:
;;   src/ — rsync'd .sls source files (relative to CWD)
;;   obj/ — compiled .so output (relative to CWD)
;; compile-library writes "next to the source" (into src/) when the
;; redirect doesn't fire, or into obj/ when it does — both are in the
;; build tree, never in the NFS source directory.
(library-directories
  (list (cons "src" "obj")
        (cons "rime" "obj")))

;; ─── Compilation options ──────────────────────────────────────────────────────
(optimize-level 2)
(generate-wpo-files #f)

;; ─── Compile rime/loop and all its sub-dependencies ──────────────────────────
(compile-imported-libraries #t)
(compile-library "rime/rime/loop.sls")
(compile-imported-libraries #f)

;; ─── Compile CREST libraries in topological order ─────────────────────────────
(printf "Compiling ~a CREST Scheme libraries~n" (length libraries))
(for-each
  (lambda (sls)
    (printf "  (~a)~n" (substring sls 0 (- (string-length sls) 4)))
    (compile-library (string-append "src/" sls)))
  libraries)

;; ─── Collect all .so files from the build workspace ───────────────────────────
;; compile-library writes to src/ (next to source) or obj/ (via redirect).
;; Scan both to find everything.
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

(define so-files (append (find-so-files "rime")
                          (find-so-files "obj")
                          (find-so-files "src")))

(printf "Creating boot file: ~a (~a .so files)~n" output-boot (length so-files))
(apply make-boot-file output-boot '("petite" "scheme") so-files)
(printf "Done.~n")
