// CallableOpInterface has no default for its methods in MLIR: an op that declares it gives all three
// clauses, and a clause that is not one of the three is an error, not something that silently does
// nothing. FunctionOpInterface extends SymbolOpInterface and CallableOpInterface, and the
// interfaces of calls extend ArgAndResultAttrsOpInterface, so an op that declares one without the
// one it extends cannot be registered. Loading such a dialect from a Scheme program reports the mistake as a
// diagnostic (CrestDialect::initialize cannot fail) and the program goes on.

// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callable-err-missing \
// RUN:   %crest-opt %s --crest-pass="passes=passes/callable-missing" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=MISSING
// RUN: not env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callable-err-unknown \
// RUN:   %crest-opt %s --crest-pass="passes=passes/callable-unknown" 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=UNKNOWN
// RUN: rm -rf %t/callable-err-function && mkdir -p %t/callable-err-function
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callable-err-function \
// RUN:   %scheme-mlir %S/passes/function-without-callable-driver.sls 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=FUNCTION

// MISSING: Failed to import Scheme library: passes/callable-missing: Exception in :interfaces: mlir::CallableOpInterface needs a clause for getArgumentTypes
// UNKNOWN: Failed to import Scheme library: passes/callable-unknown: Exception in :interfaces: mlir::CallableOpInterface has no method getCalleeRegion
// RUN: rm -rf %t/callable-err-attrs && mkdir -p %t/callable-err-attrs
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callable-err-attrs \
// RUN:   %scheme-mlir %S/passes/callable-without-attrs-driver.sls 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=ATTRS

// ATTRS: ArgAndResultAttrsOpInterface, so the op has to declare it (mlir::ArgAndResultAttrsOpInterface :standard keeps arg_attrs and res_attrs attributes): noattrs.callee
// RUN: rm -rf %t/callable-err-symbol && mkdir -p %t/callable-err-symbol
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/callable-err-symbol \
// RUN:   %scheme-mlir %S/passes/function-without-symbol-driver.sls 2>&1 \
// RUN:   | %FileCheck %s --check-prefix=SYMBOL

// SYMBOL: FunctionOpInterface extends SymbolOpInterface, so the op has to declare it, (mlir::SymbolOpInterface) for what MLIR does by default: nosymbol.func
// FUNCTION: FunctionOpInterface extends CallableOpInterface, so the op has to declare it with its three clauses: nocallable.func

module {}
