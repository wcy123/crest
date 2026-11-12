// load-scheme-dialect! gives MLIR a dialect name that the context owns: the name lives as long as the
// context, not as long as the call. MALLOC_PERTURB_ overwrites freed memory with a pattern, so a
// name that pointed into the memory of the call would print as garbage in `!dt.pair<...>`.
//
// REQUIRES: system-linux
// RUN: env MALLOC_PERTURB_=165 CREST_PATH=%S/../dialect-types CREST_SCHEME_BINARY_DIR=%t/name-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s | %FileCheck %s

// CHECK: func.func @f(%arg0: i32, %arg1: f32) -> !dt.pair<i32, f32>
// CHECK: "dt.make"(%arg0, %arg1) : (i32, f32) -> !dt.pair<i32, f32>

func.func @f(%a: i32, %b: f32) -> !dt.pair<i32, f32> {
  %0 = "dt.make"(%a, %b) : (i32, f32) -> !dt.pair<i32, f32>
  return %0 : !dt.pair<i32, f32>
}
