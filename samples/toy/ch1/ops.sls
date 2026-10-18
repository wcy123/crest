;; Toy dialect op registrations
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp — op definitions
(library (toy ch1 ops)
  (export toy-ops-initialize)
  (import (chezscheme))

  ;; Called as the :initialize callback when loading the toy dialect.
  ;; Registers all toy ops via registerDynamicOp on the dialect.
  ;; dialect-ptr: uptr to the CrestDialect instance.
  (define (toy-ops-initialize dialect-ptr)
    ;; TODO: register toy.constant, toy.transpose, toy.print,
    ;;       toy.reshape, toy.func, toy.return
    (void)))
