// The Toy tutorials inline calls with MLIR's inliner pass, as the C++ tutorial does (Ch4 onwards):
// toy.generic_call implements CallOpInterface, toy.func is callable through FunctionOpInterface,
// and toy.return declares the terminator trait (LLVM 23). toyc.sls runs createInlinerPass and has no
// inliner of its own; the dialect files declare what the pass needs; the READMEs say so.
//
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch4/toyc.sls --check-prefix=T4 --implicit-check-not=%%inline-calls!
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch5/toyc.sls --check-prefix=T5 --implicit-check-not=%%inline-calls!
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch6/toyc.sls --check-prefix=T6 --implicit-check-not=%%inline-calls!
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch7/toyc.sls --check-prefix=T7 --implicit-check-not=%%inline-calls!
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch4/toy.sls --check-prefix=D4
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch5/toy.sls --check-prefix=D5
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch6/toy.sls --check-prefix=D6
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch7/toy.sls --check-prefix=D7
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch4/README.md --check-prefix=R4
// RUN: FileCheck %s --input-file=%S/../../samples/toy/ch5/README.md --check-prefix=R5

// T4: mlir::createInlinerPass
// T5: mlir::createInlinerPass
// T6: mlir::createInlinerPass
// T7: mlir::createInlinerPass
// D4: mlir::CallOpInterface
// D4: :traits (terminator)
// D5: mlir::CallOpInterface
// D5: :traits (terminator)
// D6: mlir::CallOpInterface
// D6: :traits (terminator)
// D7: mlir::CallOpInterface
// D7: :traits (terminator)
// R4: MLIR's inliner pass
// R4-NOT: Scheme-level inliner
// R5: Toy Ch5
// R5-NOT: Scheme-level inliner

module {}
