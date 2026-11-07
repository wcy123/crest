// Before LLVM 23 a dialect that asks for traits gets a clear error, not silently ignored traits.
//
// UNSUPPORTED: llvm-23
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits22 \
// RUN:   not %crest-opt %s \
// RUN:   --crest-scheme-dialect=traittest=passes/trait-dialect 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: traittest.ret: define-op :traits requires LLVM 23+
// CHECK-SAME: requested trait: terminator

"traittest.plain"() : () -> ()
