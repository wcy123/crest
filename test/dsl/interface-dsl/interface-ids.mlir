// The TypeID that each interface of the :interfaces clause pairs with its dispatcher is a non-zero
// address, the same on every call, and different from that of every other interface. C++ finds how to
// install an interface by it (lib/Crest/Op.cpp), so an entry with another value would not be
// installed ("no way to install an interface of :interfaces").
//
// RUN: env CREST_PATH=%S %scheme-mlir %S/passes/interface-ids.sls %s | %FileCheck %s

// CHECK: (InferTypeOpInterface stable)
// CHECK: (FunctionOpInterface stable)
// CHECK: (CallableOpInterface stable)
// CHECK: (CallOpInterface stable)
// CHECK: (ArgAndResultAttrsOpInterface stable)
// CHECK: (SymbolOpInterface stable)
// CHECK: (MemoryEffectOpInterface stable)
// CHECK: (ConditionallySpeculatable stable)
// CHECK: distinct
