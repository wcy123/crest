// Bindings of operations, values, the pass manager and the log that no other test named (operation-misc.sls): moveBefore,
// getOpOperand, the type of a value changed in place, dump (to stderr), emitError, the verifier of the pass manager,
// and the log function error. emitWarning and trace are called too; MLIR drops a warning when the context has no handler for
// it, and the log level hides a trace, so there is nothing to see of them.
//
// RUN: mkdir -p %t
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/coverage-scheme \
// RUN:   %scheme-mlir %S/operation-misc.sls %s > %t/operation-misc.out 2> %t/operation-misc.err
// RUN: %FileCheck %s --input-file=%t/operation-misc.out
// RUN: %FileCheck %s --check-prefix=ERR --input-file=%t/operation-misc.err

// CHECK: the operand of t.second is the result of t.first: yes
// CHECK: order after the first move: (t.input t.second t.first builtin.module)
// CHECK: order after the second move: (t.input t.first t.second builtin.module)
// CHECK: type of the result after setType: i16
// CHECK: the pass manager runs with the verifier on: yes

// dump prints the op that setType changed.
// ERR: "t.first"(%{{.*}}) : (i32) -> i16
// ERR: error: this is an error
// ERR: [error] this is an error of the log

%a = "t.input"() : () -> i32
%0 = "t.first"(%a) : (i32) -> i32
%1 = "t.second"(%0) : (i32) -> i32
