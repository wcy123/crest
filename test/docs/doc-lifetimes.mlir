// The manual has a Lifetimes section: a handle that outlives its with- scope, a pass that is added twice,
// and a type converter that is gone when the patterns run are not errors that CREST can report.
//
// RUN: python3 %S/check-doc-lifetimes.py %S/../../docs/manual.md

module {}
