// MLIR verifies the functions of a module on several threads. The verifier of an op that Scheme
// defines runs in Scheme, which does not run on several threads, so a context that loads a Scheme
// dialect must not use threads. Without --mlir-disable-threading the process must still verify
// every function, again and again, and print the module.

// RUN: rm -rf %t/op-threading-scheme && mkdir -p %t/op-threading-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/op-threading-scheme \
// RUN:   %crest-opt %s --crest-scheme-dialect=ocb=passes/ocb > %t/op-threading-1.txt
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/op-threading-scheme \
// RUN:   %crest-opt %s --crest-scheme-dialect=ocb=passes/ocb > %t/op-threading-2.txt
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/op-threading-scheme \
// RUN:   %crest-opt %s --crest-scheme-dialect=ocb=passes/ocb > %t/op-threading-3.txt
// RUN: %FileCheck %s --input-file=%t/op-threading-1.txt
// RUN: %FileCheck %s --input-file=%t/op-threading-2.txt
// RUN: %FileCheck %s --input-file=%t/op-threading-3.txt

// CHECK-COUNT-64: "ocb.verified"() : () -> ()

module {
  func.func @f1() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f2() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f3() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f4() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f5() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f6() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f7() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f8() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f9() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f10() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f11() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f12() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f13() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f14() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f15() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f16() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f17() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f18() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f19() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f20() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f21() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f22() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f23() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f24() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f25() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f26() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f27() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f28() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f29() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f30() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f31() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f32() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f33() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f34() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f35() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f36() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f37() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f38() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f39() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f40() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f41() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f42() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f43() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f44() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f45() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f46() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f47() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f48() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f49() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f50() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f51() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f52() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f53() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f54() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f55() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f56() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f57() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f58() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f59() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f60() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f61() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f62() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f63() {
    "ocb.verified"() : () -> ()
    return
  }
  func.func @f64() {
    "ocb.verified"() : () -> ()
    return
  }
}
