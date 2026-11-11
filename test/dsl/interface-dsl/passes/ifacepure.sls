#!r6rs
;; The trait pure gives an op the side-effect interfaces with their answers: no memory effects and
;; speculatable. A clause of the op replaces one of them. Traits need LLVM 23.
(library (passes ifacepure)
  (export ifacepure)
  (import (chezscheme)
          (crest dialect)
          (only (mlir Interfaces SideEffectInterfaces) mlir::ConditionallySpeculatable))

  (define-dialect ifacepure
    (define-op pure-op :traits (pure))
    (define-op not-speculatable
      :traits (pure)
      :interfaces ((mlir::ConditionallySpeculatable (getSpeculatability (self) 0))))))
