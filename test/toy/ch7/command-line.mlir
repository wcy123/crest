// The command line of toyc is read by (rime command-line-options): options and the input file in any
// order, -h and --help, and a message for a mistake. The reading of --emit, --opt and -x and of the input from standard input is checked in driver.mlir (ch4) and the action tests.
//
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --opt --emit=ast | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls --opt --emit=ast %S/example.toy | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch7/toyc.sls --help | FileCheck %s --check-prefix=HELP
// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=xml 2>&1 | FileCheck %s --check-prefix=CHOICE
// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy -x yaml 2>&1 | FileCheck %s --check-prefix=INPUT
// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls --emit=ast %S/example.toy --nothing 2>&1 | FileCheck %s --check-prefix=UNKNOWN
// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy %S/example.toy --emit=ast 2>&1 | FileCheck %s --check-prefix=TOO-MANY

// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy -emit=ast 2>&1 | FileCheck %s --check-prefix=ONE-DASH
// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=ast -opt 2>&1 | FileCheck %s --check-prefix=SHORT-WORD
// RUN: not %scheme-mlir %samples/toy/ch7/toyc.sls %S/example.toy --emit=ast --x toy 2>&1 | FileCheck %s --check-prefix=LONG-LETTER

// AST: Module:

// HELP: Usage:
// HELP: --emit {ast,mlir,mlir-affine,mlir-llvm,llvm,jit}
// HELP: --opt
// HELP: -x {toy,mlir}
// HELP: -h, --help

// CHOICE: "xml" is not one of {{.*}} (for --emit)

// INPUT: "yaml" is not one of toy, mlir (for -x)

// A word that is not a defined option is an ordinary word, here a second input file.
// UNKNOWN: too many positional arguments: --nothing

// TOO-MANY: too many positional arguments: {{.*}}example.toy

// The C++ toyc has no -emit with one dash in its tests, and neither has this one: only --emit.
// -emit=ast is a word, not the option, so --emit is missing.
// ONE-DASH: missing required option --emit

// A long name is a word and a short name is a letter: --opt and -x, not -opt and --x.
// The words -opt and --x are not options, so they are words that no positional takes.
// SHORT-WORD: too many positional arguments: -opt
// LONG-LETTER: too many positional arguments: --x toy
