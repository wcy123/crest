#!/usr/bin/env python3
"""lit.cfg.py does not name a version of LLVM in a path.

Usage: check-lit-tool-paths.py <repo root>

An LLVM 22 tool must not be found for an LLVM 23 build: the tests would run with it.
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1]).resolve()
problems = []

lit = (root / "test/lit.cfg.py").read_text()
for match in re.finditer(r"/usr/lib/llvm-[0-9]+", lit):
    problems.append(f"test/lit.cfg.py: a path with a version of LLVM ({match.group(0)}): take it from the LLVM of the build")

if problems:
    print("\n".join(problems))
    sys.exit(1)
