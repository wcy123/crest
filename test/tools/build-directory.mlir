// The scripts that start a CREST tool do not know where it was built: CREST_BUILD_DIR says, or the tool is
// found on PATH. No path of one machine is written in them, and when the tool is not found they stop with
// a message instead of running some other build.
//
// REQUIRES: system-linux
//
// RUN: not grep -rn "/home/build" %samples/toy --include=toyc
// RUN: not grep -n "/home/build" %S/../../tools/expand-macro %S/../../tools/debug-define-dialect
// RUN: not env -u CREST_BUILD_DIR PATH=/usr/bin:/bin %samples/toy/ch3/toyc %S/x.toy 2>&1 | %FileCheck %s --check-prefix=TOYC
// RUN: not env -u CREST_BUILD_DIR PATH=/usr/bin:/bin %S/../../tools/expand-macro --file %s 2>&1 | %FileCheck %s --check-prefix=EXPAND
// RUN: not env CREST_BUILD_DIR=/nonexistent PATH=/usr/bin:/bin %samples/toy/ch3/toyc %S/x.toy 2>&1 | %FileCheck %s --check-prefix=TOYC

// TOYC: Error: scheme-mlir not found. Set CREST_BUILD_DIR or add scheme-mlir to PATH.

// EXPAND: Error: crest-opt not found. Set CREST_BUILD_DIR or add crest-opt to PATH.
