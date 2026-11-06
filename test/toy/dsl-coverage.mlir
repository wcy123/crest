// The Toy tutorials create ops with the DSL (begin-mlir-code, define-conversion-pattern), so a
// reader copies the DSL. An op built by hand with an OperationState or a typed builder must be a
// deliberate exception; check-dsl-coverage.py lists the exceptions and the reason for each.
//
// RUN: python3 %S/check-dsl-coverage.py %S/../../samples/toy

module {}
