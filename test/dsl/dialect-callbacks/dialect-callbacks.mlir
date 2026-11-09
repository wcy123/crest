// The callbacks of a Scheme dialect itself (not of its ops): the dialects it depends on are loaded
// before it is initialized, parseType and parseAttribute give the type and attribute of a pretty
// !dcb.x / #dcb.x, the dialect's canonicalization patterns are found by --canonicalize, and the
// dialect verifies the attributes that carry its name on an op and on the arguments and results
// of a function.

// RUN: rm -rf %t/dialect-callbacks-scheme && mkdir -p %t/dialect-callbacks-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/dialect-callbacks-scheme \
// RUN:   %crest-opt %s --mlir-disable-threading \
// RUN:   --crest-scheme-dialect=dcbdep=passes/dcbdep --crest-scheme-dialect=dcb=passes/dcb \
// RUN:   --canonicalize > %t/dialect-callbacks-out.txt 2> %t/dialect-callbacks-err.txt
// RUN: %FileCheck %s --check-prefix=ERR --input-file=%t/dialect-callbacks-err.txt
// RUN: %FileCheck %s --input-file=%t/dialect-callbacks-out.txt

// The dependency first, then the dialect.
// ERR: dcbdep initialize
// ERR: dcb initialize
// ERR-DAG: parse-attribute
// ERR-DAG: parse-type
// ERR-DAG: verify-op-attr dcb.holder
// ERR-DAG: verify-region-arg-attr 0 0
// ERR-DAG: verify-region-arg-attr 0 1
// ERR-DAG: verify-region-result-attr 0 0
// ERR-DAG: get-canonicalization-patterns

// The parsed attribute and type are the builtin ones the callbacks answered, and the pattern of the
// dialect made the function return its argument (the two dcb.neg stay: they are not pure).
// CHECK-LABEL: func.func @f
// CHECK:         "dcb.holder"() {attr = "hello", dcb.flag = 1 : i32}
// CHECK:         "dcb.make"() : () -> i32
// CHECK:         return %arg0

func.func @f(%a: i32 {dcb.flag = 1 : i32}, %b: i32 {dcb.flag = 2 : i32}) -> (i32 {dcb.flag = 3 : i32}) {
  %0 = "dcb.neg"(%a) : (i32) -> i32
  %1 = "dcb.neg"(%0) : (i32) -> i32
  "dcb.holder"() {attr = #dcb.foo, dcb.flag = 1 : i32} : () -> ()
  %2 = "dcb.make"() : () -> !dcb.bar
  return %1 : i32
}
