// The docs say what CREST gives up, that LLVM 22 has no :traits, that CREST_PATH runs code, and show the
// errors that a mistyped keyword and a :where guard give. Each must be there, and the messages must be the
// real ones (see check-doc-claims.py and test/docs/errors).
//
// RUN: env CREST_PATH=%samples python3 %S/check-doc-claims.py %S/../.. %crest-opt

module {}
