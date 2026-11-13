#!/usr/bin/env python3
"""The keys that the C++ bindings register follow CLAUDE.md Rule 4.

Usage: check-symbol-names.py <repo root>

- A key is registered once. A second registration of the same key silently replaces the first, and the
  header that the key names has one binding file (Rules 1 and 3).
- A key has no `/` and no `.`: an overload is told apart by the parameter types in angle brackets, as in
  `mlir::DenseElementsAttr::get<f64>`, and not by a suffix such as `/len` or `.f32`.

A key that is built from a variable or a macro is not seen here; the names of builder bindings are the three
that register_builder_binding makes from the one literal.
"""
import collections
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1]).resolve()
where = collections.defaultdict(list)
for path in sorted((root / "lib").glob("**/*.cpp")):
    text = path.read_text()
    for match in re.finditer(r'(?:Sregister_symbol|register_builder_binding)\(\s*"([^"]+)"', text):
        where[match.group(1)].append(str(path.relative_to(root)))

problems = []
for key, files in sorted(where.items()):
    if len(files) > 1:
        problems.append(f"registered {len(files)} times, the last one wins: {key} in {', '.join(files)}")
    if "/" in key or "." in key:
        problems.append(f"Rule 4 puts the types that tell an overload apart in <>, not a suffix: {key} in {files[0]}")
if len(where) < 300:
    problems.append(f"found only {len(where)} keys: the check needs updating")

if problems:
    print("\n".join(problems))
    sys.exit(1)
