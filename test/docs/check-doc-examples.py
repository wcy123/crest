#!/usr/bin/env python3
"""The examples in the docs must work when a reader copies them.

Usage: check-doc-examples.py <repo root> <crest-opt>

1. Every --crest-pass="..." in a doc uses only the options that CrestPass declares.
2. The commands of the README that name files of the repository are run, and must succeed.
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


def blocks(text):
    """Fenced blocks of a markdown text: (language, body, the 8 lines before the fence)."""
    lines = text.split("\n")
    result = []
    i = 0
    while i < len(lines):
        if lines[i].startswith("```"):
            language = lines[i][3:].strip()
            j = i + 1
            while j < len(lines) and not lines[j].startswith("```"):
                j += 1
            result.append((language, "\n".join(lines[i + 1:j]), "\n".join(lines[max(0, i - 8):i])))
            i = j
        i += 1
    return result


docs = [root / "README.md"] + sorted((root / "docs").glob("*.md")) + sorted((root / "samples").glob("**/README.md"))

# 1. The options of --crest-pass.
declared = set(re.findall(r'(?:List)?Option<[^>]*>\s+\w+\{\s*\*this,\s*"([^"]+)"',
                          (root / "lib/Passes/CrestPass.cpp").read_text()))
if not declared:
    problems.append("lib/Passes/CrestPass.cpp: found no options (the check needs updating)")
for doc in docs:
    for match in re.finditer(r'--crest-pass="?([^"\s\\]+(?:[ ][^"\\\n]*)?)"?', doc.read_text()):
        for token in match.group(1).split():
            key = token.split("=")[0]
            if "=" in token and key not in declared:
                problems.append(f"{doc.relative_to(root)}: --crest-pass has no option '{key}' "
                                f"(options: {', '.join(sorted(declared))})")

# 2. The commands of the README.
text = (root / "README.md").read_text()
for language, body, _ in blocks(text):
    if language != "bash" or "crest-opt" not in body:
        continue
    command = body.replace("\\\n", " ")
    files = re.findall(r"[\w/.\-]+\.mlir", command)
    if not files or not all((root / f).exists() for f in files):
        continue
    command = command.replace("build/tools/crest-opt/crest-opt", crest_opt)
    with tempfile.TemporaryDirectory() as binary_dir:
        result = subprocess.run(command, shell=True, cwd=root, capture_output=True, text=True,
                                env=dict(os.environ, CREST_SCHEME_BINARY_DIR=binary_dir))
    if result.returncode != 0 or not result.stdout.strip():
        problems.append(f"README.md: this command fails: {' '.join(command.split())}\n    {(result.stdout + result.stderr).strip()[:300]}")

if problems:
    print("\n".join(problems))
    sys.exit(1)
