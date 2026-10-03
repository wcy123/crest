;;===----------------------------------------------------------------------===;;
;;
;; cmake/compile_one_lib.ss — Compile a single Chez Scheme library
;;
;; Usage:
;;   scheme --script compile_one_lib.ss <src-file> <src-dir> <obj-dir> <rime-dir>
;;
;;   src-file: path to .sls relative to src-dir, e.g. "mlir/core/ir.sls"
;;   src-dir:  absolute path to the scheme/ source directory
;;   obj-dir:  absolute path to build-tree directory for .so output
;;   rime-dir: absolute path to rime source directory
;;
;; Note: compile-library in Chez 10.4.1 writes .so next to the source file
;; regardless of library-directories (source . object) settings when a file
;; path is given.  We compile to source-dir then immediately rename to obj-dir
;; so the source tree is never left dirty.  Parallel compilations are safe
;; because each library writes to a unique path.
;;
;;===----------------------------------------------------------------------===;;

(import (chezscheme))

(define args     (command-line-arguments))
(define src-file (list-ref args 0))   ; "mlir/core/ir.sls"
(define src-dir  (list-ref args 1))
(define obj-dir  (list-ref args 2))
(define rime-dir (list-ref args 3))

;; ─── Library search paths ─────────────────────────────────────────────────────
(library-directories
  (list (cons src-dir src-dir)
        (cons rime-dir rime-dir)))

;; ─── Compilation options ──────────────────────────────────────────────────────
;; optimize-level 2: balanced compile-time / runtime performance.
;; Level 3 produces faster code but compile time increases significantly.
(optimize-level 2)

;; Suppress whole-program optimization files — not needed for boot files.
(generate-wpo-files #f)

;; ─── Compile ──────────────────────────────────────────────────────────────────
;; compile-library writes .so next to the .sls in src-dir.
;; We immediately move it to obj-dir to keep the source tree clean.
(compile-library src-file)

(let* ([base     (substring src-file 0 (- (string-length src-file) 4))]
       [src-so   (string-append src-dir "/" base ".so")]
       [src-wpo  (string-append src-dir "/" base ".wpo")]
       [dest-so  (string-append obj-dir "/" base ".so")]
       [dest-dir (let loop ([s dest-so] [i (- (string-length dest-so) 1)])
                   (if (char=? (string-ref s i) #\/)
                       (substring s 0 i)
                       (loop s (- i 1))))])
  ;; Use mv (not rename-file) to handle cross-device moves
  ;; (e.g. source on NFS, build dir on local disk).
  (system (string-append "mkdir -p " dest-dir))
  (system (string-append "mv " src-so " " dest-so))
  (when (file-exists? src-wpo) (delete-file src-wpo)))
