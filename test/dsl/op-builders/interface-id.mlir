// mlir::InferTypeOpInterface::getInterfaceID answers the address that the TypeID of the interface wraps: not
// zero and the same on every call. An :interface2 entry pairs it with the dispatcher, and C++ finds how to
// install the interface by it, so an entry with another value would not be installed
// (the error "no way to install an interface of :interface2").
//
// RUN: env CREST_PATH=%S %scheme-mlir %S/interface-id-driver.sls %s | %FileCheck %s

// CHECK: stable
