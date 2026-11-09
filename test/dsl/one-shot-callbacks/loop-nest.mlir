// buildAffineLoopNest calls back with the builder of the innermost body and the induction variables,
// once, while it builds the loops.
//
// RUN: rm -rf %t/loop-nest-scheme && mkdir -p %t/loop-nest-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/loop-nest-scheme \
// RUN:   %crest-opt --crest-pass="passes=passes/loop-nest" %s \
// RUN:   > %t/loop-nest-out.txt
// RUN: %FileCheck %s --check-prefix=SAY --input-file=%t/loop-nest-out.txt
// RUN: %FileCheck %s --input-file=%t/loop-nest-out.txt

// SAY: induction variables: 2

// CHECK: affine.for %[[I:.*]] = 0 to 4 {
// CHECK:   affine.for %[[J:.*]] = 0 to 8 step 2 {

module {
}
