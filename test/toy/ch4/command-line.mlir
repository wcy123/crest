// The command line of toyc is read by (rime command-line-options): options and the input file in any
// order, -h and --help, and a message for a mistake. The reading of -emit, -opt and -x with one or two
// dashes and of the input from standard input is checked in driver.mlir (ch4) and the action tests.
//
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy -opt --emit=ast | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls -opt --emit=ast %S/example.toy | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls --help | FileCheck %s --check-prefix=HELP
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy --emit=xml 2>&1 | FileCheck %s --check-prefix=CHOICE
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy -x yaml 2>&1 | FileCheck %s --check-prefix=INPUT
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy --nothing 2>&1 | FileCheck %s --check-prefix=UNKNOWN
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy %S/example.toy -emit=ast 2>&1 | FileCheck %s --check-prefix=TOO-MANY

// AST: Module:

// HELP: Usage: toyc
// HELP: --emit {ast,mlir}
// HELP: --opt
// HELP: --x {toy,mlir}
// HELP: -h, --help

// CHOICE: toyc: argument must be one of the choices
// CHOICE-SAME: "xml"

// INPUT: toyc: argument must be one of the choices
// INPUT-SAME: "yaml"

// UNKNOWN: toyc: unknown option
// UNKNOWN-SAME: "--nothing"

// TOO-MANY: toyc: too many input files
