// A binding that raises an error must not leave C++ memory behind. The error unwinds the Scheme way,
// so no destructor of the C++ frame runs: the binding must not hold a std::string, a SmallVector or
// another object with a destructor when it raises. Raising the same error on an operation with a
// short name (a name of 15 characters or less needs no heap) and on one with a long name must grow
// the C++ heap by the same amount: what Chez itself keeps for each error is the same in both. The same
// holds for a block that Region::push_back<Block> makes before an error: it must be given to the region or
// freed, never left behind.
//
// REQUIRES: system-linux
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/error-path-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s | %FileCheck %s

// CHECK: error-path-leak: ok
// CHECK-NEXT: block-leak: ok

"a.b"() : () -> ()
"test.a_long_operation_name_that_needs_the_heap"() : () -> ()
