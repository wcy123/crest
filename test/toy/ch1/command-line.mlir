// The command line of toyc is read by (rime command-line-options): options and the input file in any
// order, -h and --help, and a message for a mistake.
//
// RUN: %scheme-mlir %samples/toy/ch1/toyc.sls %S/example.toy --emit=ast | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch1/toyc.sls --emit=ast %S/example.toy | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch1/toyc.sls --emit ast %S/example.toy | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch1/toyc.sls -h | FileCheck %s --check-prefix=HELP
// RUN: not %scheme-mlir %samples/toy/ch1/toyc.sls %S/example.toy --emit=mlir 2>&1 | FileCheck %s --check-prefix=CHOICE
// RUN: not %scheme-mlir %samples/toy/ch1/toyc.sls --emit=ast %S/example.toy --nothing 2>&1 | FileCheck %s --check-prefix=UNKNOWN
// RUN: not %scheme-mlir %samples/toy/ch1/toyc.sls %S/example.toy -emit=ast 2>&1 | FileCheck %s --check-prefix=ONE-DASH
// RUN: not %scheme-mlir %samples/toy/ch1/toyc.sls %S/example.toy %S/example.toy --emit=ast 2>&1 | FileCheck %s --check-prefix=TWO-FILES
// RUN: not %scheme-mlir %samples/toy/ch1/toyc.sls --emit=ast 2>&1 | FileCheck %s --check-prefix=NO-FILE
// RUN: not %scheme-mlir %samples/toy/ch1/toyc.sls %S/example.toy 2>&1 | FileCheck %s --check-prefix=NO-EMIT

// AST: Module:

// HELP: Usage:
// HELP: <file>
// HELP: --emit {ast}
// HELP: -h, --help

// CHOICE: argument must be one of the choices
// CHOICE-SAME: "mlir"

// A word that is not a defined option is an ordinary word, here a second input file.
// UNKNOWN: too many positional arguments
// UNKNOWN-SAME: "--nothing"

// The C++ toyc has no -emit with one dash in its tests, and neither has this one: only --emit.
// -emit=ast is a word, not the option, so --emit is missing.
// ONE-DASH: missing required option
// ONE-DASH-SAME: "--emit"

// TWO-FILES: too many positional arguments
// TWO-FILES-SAME: example.toy

// NO-FILE: too few positional arguments
// NO-FILE-SAME: "file"

// --emit is required: there is no other action to default to.
// NO-EMIT: missing required option
// NO-EMIT-SAME: "--emit"
