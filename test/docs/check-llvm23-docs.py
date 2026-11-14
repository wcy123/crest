#!/usr/bin/env python3
"""`define-op :traits` needs LLVM 23. The README and getting-started must quote the error that LLVM 22 gives,
worded as the stub of Trait.cpp words it.

Usage: check-llvm23-docs.py <repo root>
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1]).resolve()
readme = " ".join((root / "README.md").read_text().split())
getting_started = " ".join((root / "docs/getting-started.md").read_text().split())
problems = []

stub = (root / "lib/Crest/TraitStub.cpp").read_text()
message = re.search(r'"(define-op :traits requires LLVM 23\+)', stub)
if not message:
    problems.append("lib/Crest/TraitStub.cpp: the :traits message changed (the check needs updating)")
else:
    for name, text in (("README.md", readme), ("docs/getting-started.md", getting_started)):
        if message.group(1) not in text:
            problems.append(f'{name}: does not quote the LLVM 22 error "{message.group(1)}"')

if "skips about 70" not in getting_started:
    problems.append("docs/getting-started.md: does not say that check-crest on LLVM 22 skips tests")

if problems:
    print("\n".join(problems))
    sys.exit(1)
