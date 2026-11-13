// No file may point at a planning document (`plans/NN-name.md`, "plan 05"): the plans are not in the
// repository, so a reader cannot follow the reference.
//
// RUN: python3 %S/check-plan-references.py %S/../..

module {}
