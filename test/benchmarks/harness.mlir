// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

// The benchmark harness (benchmarks/run.py) runs from start to end on tiny modules. The numbers mean nothing here; the test
// checks that the tables have their parts, and that the harness checks what it must: the number of fusions in every run, and
// that the tools it compares print the same output. It stops when they do not.
//
// REQUIRES: system-linux
// UNSUPPORTED: valgrind

// The real crest-opt, with the full pass and the one-pattern pass.
// RUN: python3 %S/../../benchmarks/run.py --crest-opt tool=%crest-opt --sizes 4 8 12 --repeat 1 | %FileCheck %s

// Two tools that print the same output are compared; two that do not stop the run.
// RUN: python3 %S/../../benchmarks/run.py --crest-opt fake=%S/fake-fuse.sh --cpp-opt %S/fake-fuse.sh --sizes 4 --repeat 1 | %FileCheck %s --check-prefix=COMPARE
// RUN: not python3 %S/../../benchmarks/run.py --crest-opt fake=%S/fake-fuse.sh --cpp-opt %S/fake-fuse-other.sh --sizes 4 --repeat 1 2>&1 | %FileCheck %s --check-prefix=DIFFERENT

// A tool that fuses nothing (it prints its input) must stop the harness, not give numbers.
// RUN: printf '#!/bin/sh\nfor last; do :; done\ncat "$last"\n' > %t.tool
// RUN: chmod +x %t.tool
// RUN: not python3 %S/../../benchmarks/run.py --crest-opt fake=%t.tool --sizes 4 --repeat 1 2>&1 | %FileCheck %s --check-prefix=STOP

// The generated modules.
// RUN: python3 %S/../../benchmarks/generate-module.py 2 | %FileCheck %s --check-prefix=MATCH
// RUN: python3 %S/../../benchmarks/generate-module.py 2 --no-match | %FileCheck %s --check-prefix=NOMATCH

// CHECK: == tool hip-fusion (15 patterns):
// CHECK: start-up: {{[0-9.]+}} s
// CHECK: variant functions ops no pass s with pass s pass cost s us/function us/op spread
// CHECK: match 4 64
// CHECK: match 8 128
// CHECK: match 12 192
// CHECK: no-match 4
// CHECK: no-match 12
// CHECK: == tool qadd only (1 pattern):
// CHECK: match 12 192
// CHECK: == comparison:
// CHECK: load average at end

// COMPARE: == fake qadd only (1 pattern):
// COMPARE: == cpp C++ (1 pattern):
// COMPARE: == comparison: cost of one more function at the largest size (us/function; lower is better)
// COMPARE: match / C++ no-match / C++
// COMPARE: cpp C++ (1 pattern)

// DIFFERENT: fake qadd only (1 pattern) and cpp C++ (1 pattern) print different output for match, 4 functions: line {{[0-9]+}}

// STOP: fake hip-fusion (15 patterns), match, 4 functions: 0 hip.qadd in the output, expected 4

// MATCH: func.func @qadd_0
// MATCH: "hip.add"
// MATCH: func.func @qadd_1
// NOMATCH: "hip.sub"
// NOMATCH-NOT: "hip.add"

module {}
