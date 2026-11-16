// A build against an LLVM that CREST does not support stops at configure time and says which versions it needs, which
// one it found and where; 22 and 23 pass, and a newer one builds with a warning (check-llvm-version.py).
//
// REQUIRES: cmake
// RUN: python3 %S/check-llvm-version.py %S/../.. %cmake

module {}
