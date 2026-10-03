;;===----------------------------------------------------------------------===;;
;;
;; cmake/compile_one_lib.ss — Compile a single Chez Scheme library
;;
;; Usage (invoked by CMake via SchemeLibTargets.cmake):
;;   scheme --libdirs <scheme-src>:<rime-dir>:<obj-dir>
;;          --script compile_one_lib.ss <src-file> <src-dir> <obj-dir>
;;
;;   --libdirs includes obj-dir so compiled imports (.so) are found there.
;;   compile-library writes the .so next to the .sls (in src-dir, since
;;   scheme-src is listed first in --libdirs).  We immediately move it to
;;   obj-dir so the source tree is clean after each invocation.
;;
;;===----------------------------------------------------------------------===;;

(import (chezscheme))

(define args     (command-line-arguments))
(define src-file (list-ref args 0))   ; "mlir/core/ir.sls" (relative to src-dir)
(define src-dir  (list-ref args 1))   ; /workspace/crest/scheme (= WORKING_DIRECTORY)
(define obj-dir  (list-ref args 2))   ; /build/scheme-objs

;; ─── Compilation options ──────────────────────────────────────────────────────
;; optimize-level 2: balanced compile time vs runtime performance.
;; Level 3 produces faster code but compile time increases significantly.
(optimize-level 2)

;; No whole-program optimization files needed for boot.
(generate-wpo-files #f)

;; ─── Ensure obj-dir subtree exists ───────────────────────────────────────────
;; Pre-create the destination directory so any (source . object) redirect
;; from library-directories can write there.
(let* ([base    (substring src-file 0 (- (string-length src-file) 4))]
       [dest-so (string-append obj-dir "/" base ".so")]
       [ddir    (let loop ([i (- (string-length dest-so) 1)])
                  (if (char=? (string-ref dest-so i) #\/)
                      (substring dest-so 0 i)
                      (loop (- i 1))))])
  (system (string-append "mkdir -p " ddir)))

;; ─── Compile ──────────────────────────────────────────────────────────────────
;; --libdirs includes src-dir first so source (.sls) is found there.
;; compile-library writes the .so next to the .sls in src-dir.
;; Compiled imports (.so) are found in obj-dir (last in --libdirs).
(compile-library src-file)

;; ─── Move to obj-dir ──────────────────────────────────────────────────────────
(let* ([base    (substring src-file 0 (- (string-length src-file) 4))]
       [src-so  (string-append src-dir "/" base ".so")]
       [src-wpo (string-append src-dir "/" base ".wpo")]
       [dest-so (string-append obj-dir "/" base ".so")])
  ;; Move .so from src-dir → obj-dir.
  ;; mv -f handles cross-device (NFS→local) and overwrites any stale copy.
  (when (file-exists? src-so)
    (system (string-append "mv -f " src-so " " dest-so)))
  ;; Verify destination exists — fatal if neither redirect nor mv produced it.
  (unless (file-exists? dest-so)
    (error 'compile-one-lib "no compiled output found" dest-so))
  (when (file-exists? src-wpo)
    (delete-file src-wpo)))
