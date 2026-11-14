#!/usr/bin/env python3
"""CREST_PATH makes every directory in it a library directory, and a .sls file found there is compiled and run.
getting-started and the manual must say so, and tell the reader to trust those directories.

Usage: check-crest-path-warning.py <repo root>
"""
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve()
warning = "point `CREST_PATH` at directories you trust"
problems = []
for name in ("docs/getting-started.md", "docs/manual.md"):
    text = " ".join((root / name).read_text().split())
    if warning not in text:
        problems.append(f'{name}: no warning that CREST_PATH runs code ("{warning}")')
    if "CREST_SCHEME_BINARY_DIR" not in text:
        problems.append(f"{name}: does not say where the compiled files go (CREST_SCHEME_BINARY_DIR)")

if problems:
    print("\n".join(problems))
    sys.exit(1)
