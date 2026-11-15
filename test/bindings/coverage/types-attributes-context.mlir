// The small bindings of types, attributes and the context that no other test named (types-attributes-context.sls).
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/coverage-scheme \
// RUN:   %scheme-mlir %S/types-attributes-context.sls %s | %FileCheck %s

// CHECK: allows unregistered dialects: yes
// CHECK: threads before: no
// CHECK: threads after enable: yes
// CHECK: threads after disable: no
// CHECK: prints the op on a diagnostic: no
// CHECK: prints the op on a diagnostic again: yes
// CHECK: f16: f16
// CHECK: bf16: bf16
// CHECK: none: none
// CHECK: i1: i1
// CHECK: element type of complex<f32>: f32
// CHECK: element type of vector<4x2xi8>: i8
// CHECK: rank of vector<4x2xi8>: 2
// CHECK: memory space of memref<4xf32, 3>: 3 : i64
// CHECK: float is a FloatAttr: yes
// CHECK: string is a FloatAttr: no
// CHECK: string is a StringAttr: yes
// CHECK: float is a StringAttr: no
// CHECK: flat symbol reference: target
// CHECK: float attribute of an op: 2.5

"t.op"() {scale = 2.5 : f64} : () -> ()
