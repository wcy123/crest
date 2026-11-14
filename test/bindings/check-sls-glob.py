#!/usr/bin/env python3
"""The glob of the .sls files that the boot depends on has CONFIGURE_DEPENDS.

Usage: check-sls-glob.py <repo root>

A glob is made when cmake configures, so a file that was added later is not in the list, and the boot is not rebuilt
when that file is edited. With CONFIGURE_DEPENDS the build checks the glob again.
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1]).resolve()
problems = []

deps = (root / "cmake/deps.cmake").read_text()
for match in re.finditer(r"file\(GLOB_RECURSE\s+(\w+)(.*?)\)", deps, re.S):
    if ".sls" in match.group(2) and "CONFIGURE_DEPENDS" not in match.group(2):
        problems.append(f"cmake/deps.cmake: the glob of {match.group(1)} (.sls files) has no CONFIGURE_DEPENDS")

if problems:
    print("\n".join(problems))
    sys.exit(1)
