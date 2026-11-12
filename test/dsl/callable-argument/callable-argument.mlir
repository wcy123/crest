// A function that C++ keeps a callback in takes the address of a C function. Given a procedure, it
// raises an error that says how to make one, instead of crashing later.

// RUN: env CREST_PATH=%S %scheme-mlir %S/driver.sls | %FileCheck %s

// CHECK: conversion: the callback must be the address of a C function
// CHECK: legality: the callback must be the address of a C function
// CHECK: pattern: the callback must be the address of a C function
// CHECK: static address accepted: yes

module {}
