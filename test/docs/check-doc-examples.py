#!/usr/bin/env python3
"""The commands of the README that name files of the repository must run when a reader copies them.

Usage: check-doc-examples.py <repo root> <crest-opt>
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

for body in re.findall(r"```bash\n(.*?)```", (root / "README.md").read_text(encoding="utf-8"), re.S):
    if "crest-opt" not in body:
        continue
    command = body.replace("\\\n", " ")
    files = re.findall(r"[\w/.\-]+\.mlir", command)
    if not files or not all((root / f).exists() for f in files):
        continue
    command = command.replace("build/tools/crest-opt/crest-opt", crest_opt)
    with tempfile.TemporaryDirectory() as binary_dir:
        result = subprocess.run(command, shell=True, cwd=root, capture_output=True, text=True, encoding="utf-8",
                                env=dict(os.environ, CREST_SCHEME_BINARY_DIR=binary_dir))
    if result.returncode != 0 or not result.stdout.strip():
        problems.append(f"README.md: this command fails: {' '.join(command.split())}\n"
                        f"    {(result.stdout + result.stderr).strip()[:300]}")

if problems:
    print("\n".join(problems))
    sys.exit(1)
