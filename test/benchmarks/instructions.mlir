// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

// benchmarks/run.py --instructions counts instructions with callgrind, in parallel. With a stand-in tool the numbers mean nothing;
// the test checks that the mode runs and prints its tables and its comparison.
//
// REQUIRES: system-linux, callgrind
// UNSUPPORTED: valgrind
// RUN: python3 %S/../../benchmarks/run.py --instructions --crest-opt fake=%S/fake-fuse.sh --cpp-opt %S/fake-fuse.sh --sizes 2 4 | %FileCheck %s

// CHECK: instructions counted by callgrind; sizes [2, 4]
// CHECK: == fake hip-fusion (15 patterns):
// CHECK: start-up: {{[0-9.]+}} M instructions
// CHECK: variant functions ops no pass M with pass M pass cost M kinstr/function kinstr/op spread
// CHECK: match 2 32
// CHECK: no-match 4 64
// CHECK: == comparison: cost of one more function at the largest size (kinstr/function; lower is better)
// CHECK: cpp C++ (1 pattern)

module {}
