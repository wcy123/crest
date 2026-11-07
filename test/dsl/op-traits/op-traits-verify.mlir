// The verifier of each trait: has-parent, isolated-from-above, same-operands-and-result-shape.
//
// REQUIRES: llvm-23
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/verify \
// RUN:   %crest-opt %s --split-input-file --verify-diagnostics \
// RUN:   --crest-scheme-dialect=pt=passes/trait-ops

"pt.parent"() ({
  "pt.child"() : () -> ()
}) : () -> ()

// -----

// expected-error@+1 {{expects parent op 'pt.parent'}}
"pt.child"() : () -> ()

// -----

func.func @from_above(%a: i32) {
  // expected-note@+1 {{required by region isolation constraints}}
  "pt.island"() ({
    // expected-error@+1 {{using value defined outside the region}}
    "pt.use"(%a) : (i32) -> ()
  }) : () -> ()
  return
}

// -----

func.func @inside(%a: i32) {
  "pt.island"() ({
  ^bb0(%b: i32):
    "pt.use"(%b) : (i32) -> ()
  }) : () -> ()
  return
}

// -----

func.func @shape(%a: tensor<2xf32>, %b: tensor<3xf32>) {
  // expected-error@+1 {{requires the same shape for all operands and results}}
  %0 = "pt.same-shape"(%a) : (tensor<2xf32>) -> tensor<3xf32>
  return
}
