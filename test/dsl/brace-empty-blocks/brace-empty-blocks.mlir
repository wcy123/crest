// A block with no ops is made in its place, first, in the middle and last of its region, and the
// blocks after it still start where they should: each ^label starts a block, even when the block
// has no ops.
//
// MLIR requires a terminator in every block of a region with several blocks, so the IR that this
// test makes is not valid, and the verifier is off (so MLIR prints in the generic form).
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %crest-opt -allow-unregistered-dialect --verify-each=false \
// RUN:   --crest-pass="passes=passes/brace-empty-blocks" %s | %FileCheck %s

// CHECK-LABEL: sym_name = "empty_blocks"
// CHECK:         "test.dst_empty_blocks"() ({
// CHECK-NEXT:    ^bb0:
// CHECK-NEXT:    ^bb1:{{.*}}
// CHECK-NEXT:      "test.p"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.q"() : () -> ()
// CHECK-NEXT:    ^bb1:{{.*}}
// CHECK-NEXT:    ^bb2:{{.*}}
// CHECK-NEXT:      "test.r"() : () -> ()
// CHECK-NEXT:    }, {
// CHECK-NEXT:      "test.s"() : () -> ()
// CHECK-NEXT:    ^bb1:{{.*}}
// CHECK-NEXT:    }) : () -> ()
func.func @empty_blocks() {
  "test.empty_blocks"() : () -> ()
  return
}
