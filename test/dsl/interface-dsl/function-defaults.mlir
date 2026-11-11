// A function op that does not give verifyBody, verifyType and cloneTypeWith gets what MLIR does for
// an op that does not override them: the entry block has to match the function type, verifyType
// accepts, and the clone is a FunctionType.

// RUN: rm -rf %t/function-defaults-scheme && mkdir -p %t/function-defaults-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/function-defaults-scheme \
// RUN:   %scheme-mlir %S/passes/function-defaults.sls %s 2>&1 \
// RUN:   | %FileCheck %s

// CHECK: fdefaults.fn verifyBody: true
// CHECK: error: 'fdefaults.fn' op entry block must have 1 arguments to match function signature
// CHECK: fdefaults.fn verifyBody: false
// CHECK: error: 'fdefaults.fn' op type of entry block argument #0(f32) must match the type of the corresponding argument in function signature(i32)
// CHECK: fdefaults.fn verifyBody: false
// CHECK: fdefaults.fn verifyBody: true
// CHECK: verifyType: true
// CHECK: cloneTypeWith: (f32) -> i64

module {
  "fdefaults.fn"() ({
  ^bb0(%a: i32):
    "foo.use"(%a) : (i32) -> ()
  }) {function_type = (i32) -> (), sym_name = "matching"} : () -> ()
  "fdefaults.fn"() ({
  ^bb0(%a: i32, %b: i32):
    "foo.use"(%a) : (i32) -> ()
  }) {function_type = (i32) -> (), sym_name = "too_many_arguments"} : () -> ()
  "fdefaults.fn"() ({
  ^bb0(%a: f32):
    "foo.use"(%a) : (f32) -> ()
  }) {function_type = (i32) -> (), sym_name = "wrong_type"} : () -> ()
  "fdefaults.fn"() ({
  }) {function_type = (i32) -> (), sym_name = "external"} : () -> ()
}
