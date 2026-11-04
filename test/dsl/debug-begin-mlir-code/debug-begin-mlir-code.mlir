// CREST_DEBUG_BEGIN_MLIR_CODE=<file> appends the expansion of every begin-mlir-code
// form to <file>, each under a header with its source position. The pass library has
// two forms; both must appear, in order, in the one file.
//
// RUN: rm -rf %t %t.expanded
// RUN: env CREST_DEBUG_BEGIN_MLIR_CODE=%t.expanded CREST_PATH=%S \
// RUN:   CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect \
// RUN:   --crest-pass="passes=passes/debug-begin-mlir-code" %s \
// RUN:   | %FileCheck %s
// RUN: %FileCheck %s --check-prefix=DUMP --input-file=%t.expanded

// CHECK-LABEL: func.func @f
// CHECK:         %[[A:.*]] = "test.a"(%arg0) : (i32) -> i32
// CHECK-NEXT:    %[[B:.*]] = "test.b"(%[[A]]) : (i32) -> i32
// CHECK-NEXT:    return %[[B]] : i32

// DUMP: ;; begin-mlir-code at {{.*}}debug-begin-mlir-code.sls:{{[0-9]+}}:{{[0-9]+}}
// DUMP: (let*
// DUMP: "test.a"
// DUMP: ;; begin-mlir-code at {{.*}}debug-begin-mlir-code.sls:{{[0-9]+}}:{{[0-9]+}}
// DUMP: (let*
// DUMP: "test.b"

func.func @f(%a: i32) -> i32 {
  %0 = "test.in"(%a) : (i32) -> i32
  return %0 : i32
}
