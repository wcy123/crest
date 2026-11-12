// with-c-callable makes a C function of a procedure for the length of its body and releases it after,
// also when the body raises an error. A code object that the user made and locked is used as it is.

// RUN: %scheme-mlir %S/c-callable-driver.sls | %FileCheck %s

// CHECK: answers: 42
// CHECK: locked in the body: yes
// CHECK: locked after the body: no
// CHECK: error caught
// CHECK: locked after an error: no
// CHECK: reused answers: 42
// CHECK: reused still locked: yes
// CHECK: address answers: 101 same address: yes
// CHECK: address still locked: yes
// CHECK: unlocked code rejected
// CHECK: still not locked: yes
// CHECK: a number rejected
// CHECK: static answers: 42
// CHECK: static locked: yes
// CHECK: 300 runs released: yes

module {}
