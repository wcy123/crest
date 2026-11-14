// The manual shows the errors that a mistyped keyword and a :where guard give. The messages must be the real
// ones (see check-error-examples.py and test/docs/errors).
//
// RUN: env CREST_PATH=%samples python3 %S/check-error-examples.py %S/../.. %crest-opt

module {}
