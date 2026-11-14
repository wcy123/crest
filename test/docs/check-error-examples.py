#!/usr/bin/env python3
"""The manual shows what a mistake in a pattern looks like: a mistyped keyword, a :where guard that answers #f
and one that raises. The lines it shows must be the ones crest-opt really prints, so this runs the probe
libraries of test/docs/errors and looks for each line.

Usage: check-error-examples.py <repo root> <crest-opt>
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
manual = (root / "docs/manual.md").read_text()

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
