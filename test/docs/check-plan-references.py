#!/usr/bin/env python3
"""Check that no file points at a planning document that is not in the repository.

The planning notes (`plans/NN-name.md`, "plan 05") were never committed, so a reader cannot follow
a reference to them. Fails on every `plans/` path and on `plan <number>`.
"""
import os
import re
import sys

SKIP_DIRS = {'.git', 'build', '_deps', '__pycache__'}
SELF = {'check-plan-references.py', 'plan-references.mlir'}
REFERENCE = re.compile(r'\bplans/|\bplans? \d')


def main(root):
    problems = []
    for dirpath, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f in SELF:
                continue
            path = os.path.join(dirpath, f)
            try:
                with open(path, encoding='utf-8') as handle:
                    lines = handle.read().splitlines()
            except (UnicodeDecodeError, OSError):
                continue
            for number, line in enumerate(lines, 1):
                if REFERENCE.search(line):
                    problems.append(f'{os.path.relpath(path, root)}:{number}: {line.strip()[:100]}')
    for p in problems:
        print(p)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
