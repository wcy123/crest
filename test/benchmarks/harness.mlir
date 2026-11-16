// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.

// The benchmark harness (benchmarks/run.py) runs from start to end on tiny modules. The numbers mean nothing here; the test
// checks that the table has its parts, and that the harness itself checks the fusions: it stops when the output does not
// hold the expected number of hip.qadd.
//
// UNSUPPORTED: valgrind
// RUN: python3 %S/../../benchmarks/run.py --crest-opt tool=%crest-opt --sizes 4 8 12 --repeat 1 | %FileCheck %s
// RUN: python3 %S/../../benchmarks/generate-module.py 2 | %FileCheck %s --check-prefix=MATCH
// A tool that fuses nothing (it prints its input) must stop the harness, not give numbers.
// RUN: printf '#!/bin/sh\nfor last; do :; done\ncat "$last"\n' > %t.tool
// RUN: chmod +x %t.tool
// RUN: not python3 %S/../../benchmarks/run.py --crest-opt fake=%t.tool --sizes 4 --repeat 1 2>&1 | %FileCheck %s --check-prefix=STOP
// RUN: python3 %S/../../benchmarks/generate-module.py 2 --no-match | %FileCheck %s --check-prefix=NOMATCH

// CHECK: == tool:
// CHECK: start-up (Chez and libraries), CPU s:
// CHECK: variant functions ops no pass s with pass s pass cost us/function us/op spread
// CHECK: match 4 64
// CHECK: match 8 128
// CHECK: match 12 192
// CHECK: no-match 4
// CHECK: no-match 12
// CHECK: load average at end

// STOP: fake match 4: 0 hip.qadd in the output, expected 4

// MATCH: func.func @qadd_0
// MATCH: "hip.add"
// MATCH: func.func @qadd_1
// NOMATCH: "hip.sub"
// NOMATCH-NOT: "hip.add"

module {}
