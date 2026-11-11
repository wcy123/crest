// CallableOpInterface has no default for its methods in MLIR: an op that declares it gives all three
// clauses, and a clause that is not one of the three is an error, not something that silently does
// nothing. FunctionOpInterface extends CallableOpInterface, so an op that declares the first
// without the second cannot be registered.

// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callable-err-missing \
// RUN:   %crest-opt %s --crest-pass="passes=passes/callable-missing" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=MISSING
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callable-err-unknown \
// RUN:   %crest-opt %s --crest-pass="passes=passes/callable-unknown" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=UNKNOWN
// RUN: rm -rf %t/callable-err-function && mkdir -p %t/callable-err-function
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callable-err-function \
// RUN:   %scheme-mlir %S/passes/function-without-callable-driver.sls 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=FUNCTION

// MISSING: Failed to import Scheme library: passes/callable-missing: Exception in :interfaces: mlir::CallableOpInterface needs a clause for getArgumentTypes
// UNKNOWN: Failed to import Scheme library: passes/callable-unknown: Exception in :interfaces: mlir::CallableOpInterface has no method getCalleeRegion
// FUNCTION: FunctionOpInterface extends CallableOpInterface, so the op has to declare it with its three clauses: nocallable.func

module {}
