#!/usr/bin/env python3
"""The docs say what CREST gives up, where it needs LLVM 23, that CREST_PATH runs code, and what the errors
look like. Each of those must be there, and the error messages must be the real ones.

Usage: check-doc-claims.py <repo root> <crest-opt>
"""
import os
import pathlib
import re
import subprocess
import sys
import tempfile

root = pathlib.Path(sys.argv[1]).resolve()
crest_opt = sys.argv[2]
problems = []
readme = (root / "README.md").read_text()
getting_started = (root / "docs/getting-started.md").read_text()
manual = (root / "docs/manual.md").read_text()

# What CREST gives up.
if not re.search(r"^## What you give up$", readme, re.M):
    problems.append('README.md: no "## What you give up" section next to the comparison with DRR and PDLL')

# LLVM 23: the docs quote the error that LLVM 22 gives, as the stub of Trait.cpp words it.
stub = (root / "lib/Crest/TraitStub.cpp").read_text()
message = re.search(r'"(define-op :traits requires LLVM 23\+)', stub)
if not message:
    problems.append("lib/Crest/TraitStub.cpp: the :traits message changed (the check needs updating)")
else:
    for name, text in (("README.md", readme), ("docs/getting-started.md", getting_started)):
        if message.group(1) not in text:
            problems.append(f'{name}: does not quote the LLVM 22 error "{message.group(1)}"')

# CREST_PATH runs code.
warning = "point `CREST_PATH` at directories you trust"
for name, text in (("docs/getting-started.md", getting_started), ("docs/manual.md", manual)):
    if warning not in text:
        problems.append(f'{name}: no warning that CREST_PATH runs code ("{warning}")')

# The errors the manual shows are the ones crest-opt gives.
section = re.search(r"^### Errors you will see$(.*?)^#{2,3} ", manual, re.M | re.S)
if not section:
    problems.append('docs/manual.md: no "### Errors you will see" section')
else:
    shown = [line.strip() for block in re.findall(r"```text\n(.*?)```", section.group(1), re.S)
             for line in block.split("\n") if line.strip()]
    probe_dir = root / "test/docs/errors"
    real = ""
    for library, debug in (("typo", False), ("falsy", True), ("raises", False)):
        with tempfile.TemporaryDirectory() as binary_dir:
            env = dict(os.environ, CREST_PATH=str(probe_dir), CREST_SCHEME_BINARY_DIR=binary_dir)
            env.pop("CREST_DEBUG_MATCH", None)
            if debug:
                env["CREST_DEBUG_MATCH"] = "1"
            result = subprocess.run([crest_opt, "-allow-unregistered-dialect",
                                     f"--crest-pass=passes=passes/{library}", str(probe_dir / "input.in")],
                                    env=env, capture_output=True, text=True)
            real += result.stdout + result.stderr
    real = real.replace(str(probe_dir) + "/", "")
    if not shown:
        problems.append("docs/manual.md: the section of errors has no ```text blocks")
    for line in shown:
        if line not in real:
            problems.append(f"docs/manual.md: crest-opt does not print this line: {line}")

if problems:
    print("\n".join(problems))
    sys.exit(1)
