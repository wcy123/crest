// :traits in define-op. A dialect written in Scheme could not say that an op is a
// terminator: MLIR only treats a dynamic op as one when DynamicOpDefinition::addTrait attached
// IsTerminator. The verifier shows the difference: a block whose last op is not a terminator is
// rejected, a block ending in a traittest.ret passes.
//
// Needs LLVM 23: DynamicOpDefinition::addTrait does not exist before.
//
// REQUIRES: llvm-23
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/traits \
// RUN:   %crest-opt %s --split-input-file --verify-diagnostics \
// RUN:   --crest-scheme-dialect=traittest=passes/trait-dialect

"traittest.wrap"() ({
  "traittest.ret"() : () -> ()
}) : () -> ()

// -----

// expected-error@+2 {{block with no terminator}}
"traittest.wrap"() ({
  "traittest.plain"() : () -> ()
}) : () -> ()
