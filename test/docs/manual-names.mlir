// The manual names libraries and exports to import. Every name it lists in the bindings tables
// (section 9), in the "CREST public API" paragraph, and every other mlir:: or crest:: name in a
// code span must exist, so the manual cannot drift from the code unnoticed.
//
// RUN: python3 %S/check-manual-names.py %S/../../docs/manual.md %S/../../scheme

module {}
