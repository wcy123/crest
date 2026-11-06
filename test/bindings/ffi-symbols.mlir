// Every C symbol the Scheme sources name must be registered (CLAUDE.md Rule 14): a
// foreign-procedure, or a define-builder-binding with its three variants. A missing one only
// fails when a pass imports its library, so this reads every .sls file and checks each name.
//
// RUN: %scheme-mlir %S/check-ffi-symbols.sls %S/../../scheme

module {}
