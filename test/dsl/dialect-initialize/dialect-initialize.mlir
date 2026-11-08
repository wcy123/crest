// The :initialize clause of define-dialect runs when the dialect is created; the ops declared next
// to it are registered as well.
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/init \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=initd=passes/init-dialect \
// RUN:   | %FileCheck %s

// CHECK-DAG: initd: user initialize ran
// CHECK-DAG: %[[P:.*]] = "initd.ping"(%arg0) : (i32) -> i32

func.func @f(%a: i32) -> i32 {
  %0 = "initd.ping"(%a) : (i32) -> i32
  return %0 : i32
}
