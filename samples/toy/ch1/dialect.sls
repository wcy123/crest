;; Toy dialect registration
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp
(library (toy ch1 dialect)
  (export toy-dialect-name
          register-toy-dialect!)
  (import (chezscheme)
          (crest dialect))

  (define toy-dialect-name "toy")

  ;; Register the Toy dialect with an MLIRContext.
  ;; Ops are registered separately in (toy ch1 ops) via the :initialize callback.
  (define (register-toy-dialect! ctx initialize-fn)
    (register-dialect! ctx toy-dialect-name
                       :initialize initialize-fn)))
