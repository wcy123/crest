;; Toy dialect op registrations
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp — op definitions
(library (toy ch1 ops)
  (export toy-ops-initialize)
  (import (chezscheme)
          (crest dialect))

  ;; Called as the :initialize callback when loading the toy dialect.
  ;; dialect-ptr: uptr to the CrestDialect instance.
  (define (toy-ops-initialize dialect-ptr)
    (register-dynamic-op! dialect-ptr "toy.constant")
    (register-dynamic-op! dialect-ptr "toy.print")
    (register-dynamic-op! dialect-ptr "toy.transpose")
    (register-dynamic-op! dialect-ptr "toy.reshape")
    (register-dynamic-op! dialect-ptr "toy.mul")
    (register-dynamic-op! dialect-ptr "toy.func")
    (register-dynamic-op! dialect-ptr "toy.return")))
