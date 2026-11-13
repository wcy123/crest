// with-raii of (crest support RAII) frees its resource when the body ends, however it ends: by
// returning, by an error and by an escape. Nested uses free the inner resource first. A resource
// whose constructor raised an error is not freed (there is none).
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/raii-scheme %scheme-mlir %S/raii-driver.sls %s | %FileCheck %s

// CHECK:      make-1
// CHECK-NEXT: body-1
// CHECK-NEXT: (free 1)
// CHECK-NEXT: result
// CHECK-NEXT: (free 2)
// CHECK-NEXT: caught
// CHECK-NEXT: (free 3)
// CHECK-NEXT: both
// CHECK-NEXT: (free 5)
// CHECK-NEXT: (free 4)
// CHECK-NEXT: caught-constructor
// CHECK-NOT:  (free
