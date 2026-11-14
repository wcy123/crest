// A pass written in Scheme runs Scheme, which runs on one thread. MLIR runs a pass that is nested on
// func.func on several threads when the context allows threads. A context that Scheme makes does not, but
// a program can enable them: the pass then has to say so, and not abort the process.
//
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/threads \
// RUN:   %scheme-mlir %S/driver.sls %s threads 2>&1 | FileCheck %s

// CHECK: error: pass tag-functions: needs a context with multithreading disabled
// CHECK: pipeline failed

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
