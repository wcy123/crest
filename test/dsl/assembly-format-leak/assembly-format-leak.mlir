// A module whose ops have an assembly format with operand lists leaves no C++ memory behind when it is
// parsed: the parser frees the lists of unresolved operands that it makes. Parsing the same text
// 3000 times must not grow the C++ heap.
//
// REQUIRES: system-linux
// It measures the heap of the process, which valgrind's allocator changes:
// UNSUPPORTED: valgrind
// RUN: env CREST_PATH=%S/../assembly-format CREST_SCHEME_BINARY_DIR=%t/af-leak \
// RUN:   %scheme-mlir %S/driver.sls %s | %FileCheck %s

// CHECK: assembly-format-leak: ok

func.func @f(%arg0: i32) {
  %0 = af.unary %arg0 : i32 to f32
  %1 = af.plus %arg0, %arg0 : i32, i32 -> i64
  %2 = af.all(%arg0, %arg0) : (i32, i32) -> f32
  af.ret %arg0 : i32
}
