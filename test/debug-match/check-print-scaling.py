#!/usr/bin/env python3
"""Printing one op costs the same in a small module and in a large one.

Usage: check-print-scaling.py <scheme-mlir> <samples dir> <print-scaling.sls>

The warnings of a failed match print the op that failed (`actual: ...`). The default flags of Operation::print number
every value of the whole module first, so with the module 25 times bigger one print took 25 times longer, and the
warnings of a big module together took the square of its size. The ratio of the two times has to stay near 1.
"""
import os
import re
import subprocess
import sys
import tempfile

scheme_mlir, samples, probe = sys.argv[1:4]
function = '''func.func @f%d(%%a: i32) -> i32 {
  %%0 = "t.op"() : () -> i32
  %%1 = "t.op"() : () -> i32
  return %%0 : i32
}
'''
with tempfile.TemporaryDirectory() as directory:
    paths = []
    for name, count in (("small", 200), ("large", 5000)):
        path = f"{directory}/{name}.mlir"
        with open(path, "w") as out:
            out.write("module {\n" + "".join(function % i for i in range(count)) + "}\n")
        paths.append(path)
    env = dict(os.environ, CREST_PATH=samples, CREST_SCHEME_BINARY_DIR=f"{directory}/bin")
    result = subprocess.run([scheme_mlir, probe] + paths, env=env, capture_output=True, text=True)

print(result.stdout + result.stderr, end="")
match = re.search(r"ratio: ([0-9.e+-]+)", result.stdout)
if not match:
    print("the probe did not print a ratio")
    sys.exit(1)
if float(match.group(1)) > 3:
    print(f"printing one op takes {match.group(1)} times longer in the large module: it grows with the size of the module")
    sys.exit(1)
