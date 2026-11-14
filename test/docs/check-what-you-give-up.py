#!/usr/bin/env python3
"""The README compares CREST with DRR and PDLL. It must also say what CREST gives up, and the two claims
"no rebuild" (the top of the README and the sentence under the comparison) must say that they hold in
development mode only.

Usage: check-what-you-give-up.py <repo root>
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1]).resolve()
readme = " ".join((root / "README.md").read_text(encoding="utf-8").split())
problems = []

section = re.search(r"## What you give up (.*?) ## ", readme)
if not section:
    problems.append('README.md: no "## What you give up" section next to the comparison with DRR and PDLL')
else:
    for name in ("Checks when the project builds", "A shared matcher", "Numbers", "No rebuild only in development mode"):
        if f"**{name}.**" not in section.group(1):
            problems.append(f'README.md: "What you give up" has no item "{name}"')

for claim in ("no rebuild, no relink, changes take effect immediately", "with no rebuild"):
    for match in re.finditer(re.escape(claim), readme):
        if "development mode" not in readme[match.start():match.end() + 60]:
            problems.append(f'README.md: "{claim}" does not say "development mode"')

if problems:
    print("\n".join(problems))
    sys.exit(1)
