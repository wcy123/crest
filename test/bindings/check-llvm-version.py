#!/usr/bin/env python3
"""cmake/check-llvm-version.cmake stops a build against an LLVM that CREST does not support, and says why.

Usage: check-llvm-version.py <repo root> <cmake>
"""
import pathlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1]).resolve()
cmake = sys.argv[2]
script = root / "cmake/check-llvm-version.cmake"
problems = []


def run(version):
    return subprocess.run([cmake, f"-DLLVM_VERSION={version}", "-DLLVM_DIR=/somewhere/lib/cmake/llvm", "-P", str(script)],
                          capture_output=True, text=True)


if not script.exists():
    print(f"{script.relative_to(root)} does not exist")
    sys.exit(1)

for version in ("22.1.8", "23.1.5"):
    result = run(version)
    if result.returncode != 0:
        problems.append(f"LLVM {version} is supported and was refused: {result.stderr.strip()}")
for version in ("21.1.0", "15.0.7"):
    result = run(version)
    if result.returncode == 0:
        problems.append(f"LLVM {version} was accepted")
    elif "22" not in result.stderr or version not in result.stderr or "/somewhere/lib/cmake/llvm" not in result.stderr:
        problems.append(f"the message for LLVM {version} does not say the versions that CREST needs, the one found and where: {result.stderr.strip()}")
result = run("24.0.0")
if result.returncode != 0 or "Warning" not in result.stderr:
    problems.append(f"LLVM 24 should build with a warning that it is not tested, got exit {result.returncode}: {result.stderr.strip()}")

if problems:
    print("\n".join(problems))
    sys.exit(1)
