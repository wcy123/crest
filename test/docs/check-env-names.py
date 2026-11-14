#!/usr/bin/env python3
"""An environment variable that CREST reads and a doc names starts with CREST_.

Usage: check-env-names.py <repo root>

CREST_PATH, CREST_SCHEME_BINARY_DIR, CREST_DEBUG_MATCH and CREST_DEBUG_BEGIN_MLIR_CODE share one prefix so that they
cannot be taken for the variable of another program. The variables that only the shell script of a tool gives to its own
Scheme (EXPAND_MACRO_*) are not in the docs and are not checked.
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1]).resolve()
read = set()
for pattern in ("scheme/**/*.sls", "lib/**/*.cpp", "lib/**/*.h", "tools/**/*"):
    for path in root.glob(pattern):
        if path.is_file():
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            read |= set(re.findall(r'(?:getenv\s*"|GetEnv\("|getenv\(")([A-Z][A-Z0-9_]*)"', text))
if len(read) < 4:
    print(f"found only {sorted(read)}: the check needs updating")
    sys.exit(1)

problems = []
docs = [root / "README.md"] + sorted((root / "docs").glob("*.md")) + sorted((root / "samples").glob("**/README.md"))
for doc in docs:
    text = doc.read_text(encoding="utf-8")
    for name in sorted(read):
        if not name.startswith("CREST_") and re.search(r"(?<![A-Z0-9_])" + name + r"(?![A-Z0-9_])", text):
            problems.append(f"{doc.relative_to(root)}: {name} is read by CREST and should start with CREST_")
if problems:
    print("\n".join(problems))
    sys.exit(1)
