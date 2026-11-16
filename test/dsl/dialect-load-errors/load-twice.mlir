// A dialect that Scheme loads into a context again is not loaded again: the dialect that is there stays,
// whatever library the second call names. (Loading it again would end the process.) A dialect that
// loads without its interfaces is an error, and not a dialect that has no ops.
//
// RUN: rm -rf %t/load-twice-scheme && mkdir -p %t/load-twice-scheme
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/load-twice-scheme \
// RUN:   %scheme-mlir %S/load-twice.sls 2>&1 | %FileCheck %s

// CHECK: first: ok
// CHECK: same library again: ok
// CHECK: other library: ok
// CHECK: bad interface: error: {{.*}}no way to install an interface
