// Before LLVM 23 a dialect that asks for traits gets a clear error, not silently ignored traits. The error is raised
// by :initialize, which has no result in MLIR, so the process ends with the text.
//
// UNSUPPORTED: llvm-23
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits22 \
// RUN:   %crest-opt %s \
// RUN:   --crest-pass="dialects-in-scheme=traittest=passes/trait-dialect passes=passes/identity" 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: traittest.ret: define-op :traits requires LLVM 23+
// CHECK-SAME: requested trait: terminator

module {}
