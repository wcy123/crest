// The README and getting-started say that `define-op :traits` needs LLVM 23, and quote the error that LLVM 22
// gives, as TraitStub.cpp words it (see check-llvm23-docs.py).
//
// RUN: python3 %S/check-llvm23-docs.py %S/../..

module {}
