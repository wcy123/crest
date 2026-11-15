// A pass written in Scheme that is nested on func.func runs on several threads of MLIR when the context
// has multithreading enabled (the program asks for it: a context made from Scheme starts without). The
// pass allocates, so collections happen while other threads run it. Every function must be tagged, again
// and again, with no abort and no hang.
//
// RUN: rm -rf %t && mkdir -p %t
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/threads \
// RUN:   %scheme-mlir %S/driver.sls %s threads > %t/threads-1.txt
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/threads \
// RUN:   %scheme-mlir %S/driver.sls %s threads > %t/threads-2.txt
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/threads \
// RUN:   %scheme-mlir %S/driver.sls %s threads > %t/threads-3.txt
// RUN: %FileCheck %s --input-file=%t/threads-1.txt
// RUN: %FileCheck %s --input-file=%t/threads-2.txt
// RUN: %FileCheck %s --input-file=%t/threads-3.txt

// CHECK-COUNT-64: func.func @f{{[0-9]+}}() attributes {tagged = "yes"}
// CHECK: passes ran: 0

func.func @f1() {
  return
}

func.func @f2() {
  return
}

func.func @f3() {
  return
}

func.func @f4() {
  return
}

func.func @f5() {
  return
}

func.func @f6() {
  return
}

func.func @f7() {
  return
}

func.func @f8() {
  return
}

func.func @f9() {
  return
}

func.func @f10() {
  return
}

func.func @f11() {
  return
}

func.func @f12() {
  return
}

func.func @f13() {
  return
}

func.func @f14() {
  return
}

func.func @f15() {
  return
}

func.func @f16() {
  return
}

func.func @f17() {
  return
}

func.func @f18() {
  return
}

func.func @f19() {
  return
}

func.func @f20() {
  return
}

func.func @f21() {
  return
}

func.func @f22() {
  return
}

func.func @f23() {
  return
}

func.func @f24() {
  return
}

func.func @f25() {
  return
}

func.func @f26() {
  return
}

func.func @f27() {
  return
}

func.func @f28() {
  return
}

func.func @f29() {
  return
}

func.func @f30() {
  return
}

func.func @f31() {
  return
}

func.func @f32() {
  return
}

func.func @f33() {
  return
}

func.func @f34() {
  return
}

func.func @f35() {
  return
}

func.func @f36() {
  return
}

func.func @f37() {
  return
}

func.func @f38() {
  return
}

func.func @f39() {
  return
}

func.func @f40() {
  return
}

func.func @f41() {
  return
}

func.func @f42() {
  return
}

func.func @f43() {
  return
}

func.func @f44() {
  return
}

func.func @f45() {
  return
}

func.func @f46() {
  return
}

func.func @f47() {
  return
}

func.func @f48() {
  return
}

func.func @f49() {
  return
}

func.func @f50() {
  return
}

func.func @f51() {
  return
}

func.func @f52() {
  return
}

func.func @f53() {
  return
}

func.func @f54() {
  return
}

func.func @f55() {
  return
}

func.func @f56() {
  return
}

func.func @f57() {
  return
}

func.func @f58() {
  return
}

func.func @f59() {
  return
}

func.func @f60() {
  return
}

func.func @f61() {
  return
}

func.func @f62() {
  return
}

func.func @f63() {
  return
}

func.func @f64() {
  return
}
