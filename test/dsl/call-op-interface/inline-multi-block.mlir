// The inliner asks the dialect's inliner interface to handle the terminator of a callee with more
// than one block through handleTerminator/block (a callee of one block goes through
// handleTerminator/value, which call-op-interface.mlir covers). The handler leaves the terminator
// alone, so the output is not valid: --verify-each=0.
//
// REQUIRES: llvm-23
// RUN: rm -rf %t/inline-multi-block-scheme && mkdir -p %t/inline-multi-block-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/inline-multi-block-scheme \
// RUN:   %crest-opt %s --verify-each=0 \
// RUN:   --crest-scheme-dialect=callblocks=passes/call-blocks-dialect \
// RUN:   --inline > %t/inline-multi-block-out.txt
// RUN: %FileCheck %s --check-prefix=SAY --input-file=%t/inline-multi-block-out.txt
// RUN: %FileCheck %s --input-file=%t/inline-multi-block-out.txt

// SAY: handleTerminator/block

// CHECK-NOT: callblocks.call
// CHECK: sym_name = "main"

module {
  "callblocks.func"() ({
  ^bb0(%a: i32):
    cf.br ^bb1
  ^bb1:
    "callblocks.ret"(%a) : (i32) -> ()
  }) {function_type = (i32) -> i32, sym_name = "callee", sym_visibility = "private"} : () -> ()
  "callblocks.func"() ({
  ^bb0(%x: i32):
    %r = "callblocks.call"(%x) {callee = @callee} : (i32) -> i32
    "callblocks.ret"(%r) : (i32) -> ()
  }) {function_type = (i32) -> i32, sym_name = "main"} : () -> ()
}
