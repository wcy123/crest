// The Toy tutorials inline calls with a Scheme-level inliner in toyc.sls, not with MLIR's inliner:
// MLIR's inliner needs toy.return to be a terminator, which a dialect written in Scheme can declare
// only on LLVM 23 (:traits), and the tutorials also build on LLVM 22. The READMEs and comments must say so, not claim that MLIR's inliner
// runs, so a reader is not sent looking for a pass that is not there.
//
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch4/README.md --check-prefix=R4
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch5/README.md --check-prefix=R5
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch5/toyc.sls --check-prefix=T5
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch4/toy.sls --check-prefix=D4
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch5/toy.sls --check-prefix=D5
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch6/toy.sls --check-prefix=D6
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch7/toy.sls --check-prefix=D7

// R4: Toy Ch4
// R4-NOT: runs MLIR's inliner
// R4-NOT: enables MLIR's generic inliner
// R5: Toy Ch5
// R5-NOT: createInlinerPass
// T5: Toy compiler Ch5
// T5-NOT: createInlinerPass
// D4: Toy dialect
// D4-NOT: so MLIR's inliner can inline
// D5: Toy dialect
// D5-NOT: so MLIR's inliner can inline
// D6: Toy dialect
// D6-NOT: so MLIR's inliner can inline
// D7: Toy dialect
// D7-NOT: so MLIR's inliner can inline

module {}
