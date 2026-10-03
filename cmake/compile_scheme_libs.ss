;;===----------------------------------------------------------------------===;;
;;
;; cmake/compile_scheme_libs.ss — Compile CREST Scheme libraries into a boot file
;;
;; Usage (invoked by CMake):
;;   scheme --script compile_scheme_libs.ss <object-dir> <output-boot>
;;
;; WORKING_DIRECTORY must be set to the scheme/ source directory by CMake.
;; Compiled .so/.wpo files go to <object-dir>, never to the source tree.
;; This is safe for FetchContent / read-only source mounts.
;;
;;===----------------------------------------------------------------------===;;

(import (chezscheme))

(define args        (command-line-arguments))
(define output-boot (list-ref args 0))
;; --libdirs (set by CMake) already configures library search paths including rime.
;; compile-library writes .so/.wpo next to the source file (CWD = scheme/).
;; We delete them after make-boot-file so the source tree is clean.

(define libraries
  ;; Dependency order: leaves first, root last.
  '(;; Foundational
    "mlir/core/logging"
    "mlir/core/context"
    "mlir/core/types"
    ;; Core IR
    "mlir/core/attribute"
    "mlir/core/value"
    "mlir/core/operation"
    "mlir/core/conversion"
    "mlir/core/builder"
    "mlir/core/ir"
    ;; Dialects
    "mlir/dialects/func"
    "mlir/dialects/shape"
    "mlir/dialects/tensor"
    ;; DDR pattern DSL
    "mlir/ddr/keywords"
    "mlir/ddr/ast"
    "mlir/ddr/parse"
    "mlir/ddr/validate"
    "mlir/ddr/actions"
    "mlir/ddr/analyze"
    "mlir/ddr/codegen"
    "mlir/ddr/rewrite"
    "mlir/ddr"
    ;; Hip dialect helpers
    "mlir/hip/fusion"
    ;; Hip fusion pass (sub-libraries before top-level)
    "passes/hip-fusion/helpers"
    "passes/hip-fusion/qadd"
    "passes/hip-fusion/qmul"
    "passes/hip-fusion/qmatmul"
    "passes/hip-fusion/qgemm"
    "passes/hip-fusion/qconv"
    "passes/hip-fusion/qsigmoid"
    "passes/hip-fusion/qlpnorm"
    "passes/hip-fusion/qdq-roundtrip"
    "passes/hip-fusion"))

(printf "Compiling ~a CREST Scheme libraries into ~a~n" (length libraries) output-boot)

(for-each
  (lambda (lib)
    (printf "  (~a)~n" lib)
    (compile-library (string-append lib ".sls")))
  libraries)

(printf "Creating boot file: ~a~n" output-boot)

(apply make-boot-file
  output-boot
  '("petite" "scheme")
  (map (lambda (lib) (string-append lib ".so")) libraries))

;; Clean up compiled artifacts from the source tree.
;; The information is now captured in the boot file.
(for-each
  (lambda (lib)
    (for-each
      (lambda (ext)
        (let ([f (string-append lib ext)])
          (when (file-exists? f) (delete-file f))))
      '(".so" ".wpo")))
  libraries)

(printf "Done.~n")
