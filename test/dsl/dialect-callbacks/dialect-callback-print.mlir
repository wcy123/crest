// The :print-type of a dialect prints the types of the dialect, and Scheme can print into the printer
// it gets (an mlir::AsmPrinter): a keyword, a nested type, a nested attribute and raw text.
// dcp.pair is parsed as dcp.pair<i32, f32> and printed as dcp.pair<i32 & f32>.
//
// RUN: rm -rf %t/dialect-callback-print-scheme && mkdir -p %t/dialect-callback-print-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/dialect-callback-print-scheme \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=dcp=passes/dcbprint | %FileCheck %s

// CHECK: func.func @f(%arg0: i32, %arg1: f32) -> !dcp.pair<i32 & f32>
// CHECK: %[[P:.*]] = "dcp.make"(%arg0, %arg1) : (i32, f32) -> !dcp.pair<i32 & f32>

func.func @f(%a: i32, %b: f32) -> !dcp.pair<i32, f32> {
  %0 = "dcp.make"(%a, %b) : (i32, f32) -> !dcp.pair<i32, f32>
  return %0 : !dcp.pair<i32, f32>
}
