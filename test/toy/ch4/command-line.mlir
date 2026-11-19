// The command line of toyc is read by (rime command-line-options): options and the input file in any
// order, -h and --help, and a message for a mistake. The reading of --emit, --opt and -x and of the input from standard input is checked in driver.mlir (ch4) and the action tests.
//
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy --opt --emit=ast | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls --opt --emit=ast %S/example.toy | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls --help | FileCheck %s --check-prefix=HELP
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy --emit=xml 2>&1 | FileCheck %s --check-prefix=CHOICE
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy -x yaml 2>&1 | FileCheck %s --check-prefix=INPUT
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy --nothing 2>&1 | FileCheck %s --check-prefix=UNKNOWN
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy %S/example.toy --emit=ast 2>&1 | FileCheck %s --check-prefix=TOO-MANY

// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy -emit=ast 2>&1 | FileCheck %s --check-prefix=ONE-DASH
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy --emit=ast -opt 2>&1 | FileCheck %s --check-prefix=SHORT-WORD
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy --emit=ast --x toy 2>&1 | FileCheck %s --check-prefix=LONG-LETTER

// AST: Module:

// HELP: Usage:
// HELP: --emit {ast,mlir}
// HELP: --opt
// HELP: -x {toy,mlir}
// HELP: -h, --help

// CHOICE: argument must be one of the choices
// CHOICE-SAME: "xml"

// INPUT: argument must be one of the choices
// INPUT-SAME: "yaml"

// UNKNOWN: unknown option
// UNKNOWN-SAME: "--nothing"

// TOO-MANY: too many positional arguments
// TOO-MANY-SAME: example.toy

// The C++ toyc has no -emit with one dash in its tests, and neither has this one: only --emit.
// ONE-DASH: unknown option
// ONE-DASH-SAME: "-emit=ast"

// A long name is a word and a short name is a letter: --opt and -x, not -opt and --x.
// SHORT-WORD: unknown option
// SHORT-WORD-SAME: "-opt"
// LONG-LETTER: unknown option
// LONG-LETTER-SAME: "--x"
