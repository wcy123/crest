#!/usr/bin/env python3
"""Rules of the build files that a test can read.

Usage: check-build-hygiene.py <repo root>

- The Chez build does not have a number of jobs in its text (make -j8): it uses CREST_CHEZ_JOBS, which defaults to
  the cores of the machine.
- The list of .sls files that the boot depends on is a glob with CONFIGURE_DEPENDS: a glob is made when cmake
  configures, so a file that was added later is not in the list, and the boot is not rebuilt when it is edited.
- lit.cfg.py does not name a version of LLVM in a path: an LLVM 22 tool must not be found for an LLVM 23 build.
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1]).resolve()
problems = []

deps = (root / "cmake/deps.cmake").read_text()
if re.search(r"make\s+-j\s*[0-9]+", deps):
    problems.append("cmake/deps.cmake: the Chez build has a fixed number of jobs (make -j<number>); use CREST_CHEZ_JOBS")
if "CREST_CHEZ_JOBS" not in (root / "cmake/crest-options.cmake").read_text():
    problems.append("cmake/crest-options.cmake: no CREST_CHEZ_JOBS option")

for match in re.finditer(r"file\(GLOB_RECURSE\s+(\w+)(.*?)\)", deps, re.S):
    if ".sls" in match.group(2) and "CONFIGURE_DEPENDS" not in match.group(2):
        problems.append(f"cmake/deps.cmake: the glob of {match.group(1)} (.sls files) has no CONFIGURE_DEPENDS")

lit = (root / "test/lit.cfg.py").read_text()
for match in re.finditer(r"/usr/lib/llvm-[0-9]+", lit):
    problems.append(f"test/lit.cfg.py: a path with a version of LLVM ({match.group(0)}): take it from the LLVM of the build")

if problems:
    print("\n".join(problems))
    sys.exit(1)
