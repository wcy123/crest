;;===----------------------------------------------------------------------===;;
;;
;; cmake/compile_scheme_libs.ss — Compile CREST Scheme libraries into a boot file
;;
;; Invoked by CMake after ChezScheme is built:
;;   scheme --libdirs <scheme-dir>:<rime-dir> --script compile_scheme_libs.ss \
;;          <output-boot-file>
;;
;; Compiles all (mlir ...) libraries in dependency order, then bundles
;; them into a single crest.boot file that can be embedded in the binary.
;; At runtime, loading crest.boot pre-instantiates all libraries so no
;; .sls files are needed on the deployment machine.
;;
;;===----------------------------------------------------------------------===;;

(import (chezscheme))

(define output-boot (car (command-line-arguments)))

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
    "mlir/ddr"))

(printf "Compiling ~a CREST Scheme libraries...~n" (length libraries))

(for-each
  (lambda (lib)
    (printf "  compiling (~a)~n" lib)
    (compile-library (string-append lib ".sls")))
  libraries)

(printf "Creating boot file: ~a~n" output-boot)

(apply make-boot-file
  output-boot
  '("petite" "scheme")
  (map (lambda (lib) (string-append lib ".so")) libraries))

(printf "Done.~n")
