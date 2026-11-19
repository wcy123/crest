// The command line of toyc is read by (rime command-line-options): options and the input file in any
// order, -h and --help, and a message for a mistake.
//
// RUN: %scheme-mlir %samples/toy/ch1/toyc.sls %S/example.toy --emit=ast | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch1/toyc.sls --emit=ast %S/example.toy | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch1/toyc.sls --emit ast %S/example.toy | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch1/toyc.sls -h | FileCheck %s --check-prefix=HELP
// RUN: not %scheme-mlir %samples/toy/ch1/toyc.sls %S/example.toy --emit=mlir 2>&1 | FileCheck %s --check-prefix=CHOICE
// RUN: not %scheme-mlir %samples/toy/ch1/toyc.sls %S/example.toy --nothing 2>&1 | FileCheck %s --check-prefix=UNKNOWN
// RUN: not %scheme-mlir %samples/toy/ch1/toyc.sls %S/example.toy %S/example.toy 2>&1 | FileCheck %s --check-prefix=TOO-MANY

// RUN: not %scheme-mlir %samples/toy/ch1/toyc.sls %S/example.toy -emit=ast 2>&1 | FileCheck %s --check-prefix=ONE-DASH

// AST: Module:

// HELP: Usage: toyc
// HELP: --emit {ast}
// HELP: -h, --help

// CHOICE: toyc: argument must be one of the choices
// CHOICE-SAME: "mlir"

// UNKNOWN: toyc: unknown option
// UNKNOWN-SAME: "--nothing"

// TOO-MANY: toyc: too many input files

// The C++ toyc has no -emit with one dash in its tests, and neither has this one: only --emit.
// ONE-DASH: toyc: unknown option
// ONE-DASH-SAME: "-emit=ast"
