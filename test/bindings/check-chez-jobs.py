#!/usr/bin/env python3
"""The Chez build does not have a number of jobs in its text (make -j8).

Usage: check-chez-jobs.py <repo root>

It uses CREST_CHEZ_JOBS, which defaults to the cores of the machine.
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

if problems:
    print("\n".join(problems))
    sys.exit(1)
