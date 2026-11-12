// A block that a pattern makes for the region of an op is made through the builder of the pattern, so
// that the conversion knows it. A conversion that fails rolls back what its patterns made, blocks
// included. Failing the same conversion 1500 times with a pattern that makes a block, and with one
// that makes none, must grow the C++ heap by the same amount.
//
// REQUIRES: system-linux
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/block-scheme \
// RUN:   %scheme-mlir %S/driver.sls %s 2>/dev/null | %FileCheck %s

// CHECK: conversion-block-leak: ok

func.func @f() {
  "test.a"() : () -> ()
  "test.bad"() : () -> ()
  return
}
