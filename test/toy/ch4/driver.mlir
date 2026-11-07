// The toyc driver as the C++ one: -emit and -opt with one or two dashes, the input from standard
// input when it is "-" or missing, -x selects the kind of input, and the messages and exit status of
// toyc.cpp for the usual mistakes.
//
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls -emit=ast < %S/example.toy | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls - --emit=ast < %S/example.toy | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy -emit ast | FileCheck %s --check-prefix=AST
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy -emit=mlir -opt | FileCheck %s --check-prefix=MLIR
// RUN: %scheme-mlir %samples/toy/ch4/toyc.sls -x mlir %S/driver-input.txt -emit=mlir | FileCheck %s --check-prefix=MLIR-IN
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls -x mlir %S/driver-input.txt -emit=ast 2>&1 | FileCheck %s --check-prefix=AST-OF-MLIR
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/example.toy 2>&1 | FileCheck %s --check-prefix=NOACTION
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/does-not-exist.toy -emit=ast 2>&1 | FileCheck %s --check-prefix=MISSING
// RUN: not %scheme-mlir %samples/toy/ch4/toyc.sls %S/driver-bad.mlir.txt -x mlir -emit=mlir 2>&1 | FileCheck %s --check-prefix=BADMLIR

// AST: Module:
// MLIR: module {
// MLIR-IN: toy.func @from_mlir
// AST-OF-MLIR: Can't dump a Toy AST when the input is MLIR
// NOACTION: No action specified (parsing only?), use -emit=<action>
// MISSING: Could not open input file
// BADMLIR: Error can't load file
