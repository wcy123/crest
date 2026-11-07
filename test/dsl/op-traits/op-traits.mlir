// Op traits and effects of Scheme ops (plans/18). `pure` makes the op free of memory effects and
// speculatable, which is what the canonicalizer (dead code) and CSE ask through the effect
// interfaces; an op without the trait is assumed to have effects and is kept.
//
// REQUIRES: llvm-23
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=pt=passes/trait-ops --canonicalize | %FileCheck %s --check-prefix=DCE
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits2 \
// RUN:   %crest-opt %s --mlir-disable-threading --crest-scheme-dialect=pt=passes/trait-ops --cse | %FileCheck %s --check-prefix=CSE

// DCE-LABEL: func.func @dead
// DCE-NOT:     "pt.pure"
// DCE:         "pt.impure"
// DCE-NEXT:    return

// CSE-LABEL: func.func @repeated
// CSE:         %[[P:.*]] = "pt.pure"(%arg0)
// CSE-NOT:     "pt.pure"
// CSE:         %[[I1:.*]] = "pt.impure"(%arg0)
// CSE:         %[[I2:.*]] = "pt.impure"(%arg0)
// CSE:         return %[[P]]

func.func @dead(%a: i32) -> i32 {
  %0 = "pt.pure"(%a) : (i32) -> i32
  %1 = "pt.impure"(%a) : (i32) -> i32
  return %a : i32
}

func.func @repeated(%a: i32) -> i32 {
  %0 = "pt.pure"(%a) : (i32) -> i32
  %1 = "pt.pure"(%a) : (i32) -> i32
  %2 = "pt.impure"(%a) : (i32) -> i32
  %3 = "pt.impure"(%a) : (i32) -> i32
  return %1 : i32
}
