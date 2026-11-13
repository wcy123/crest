#!/usr/bin/env python3
"""Check that every library under scheme/ lives at the path of its name.

(mlir IR BuiltinTypes) is scheme/mlir/IR/BuiltinTypes.sls (CLAUDE.md Rule 2), under the one root
scheme/, so a name has one place. Also fails when two library names differ only by case: on a
case-insensitive file system (Windows, macOS) they would be the same directory.
"""
import importlib.util
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('names', os.path.join(here, '..', 'docs', 'check-manual-names.py'))
names = importlib.util.module_from_spec(spec)
spec.loader.exec_module(names)


def main(root):
    problems, seen = [], {}
    for dirpath, _, files in os.walk(root):
        for f in sorted(files):
            if not f.endswith('.sls'):
                continue
            path = os.path.join(dirpath, f)
            toks = names.tokens(open(path, encoding='utf-8').read())
            try:
                name, _ = names.read_forms(toks, toks.index('library') + 1)
            except (ValueError, IndexError):
                continue
            rel = os.path.relpath(path, root).replace(os.sep, '/')
            expected = '/'.join(name) + '.sls'
            if rel != expected:
                problems.append(f'{rel}: library ({" ".join(name)}) belongs in {expected}')
            for i in range(1, len(name) + 1):
                prefix = ' '.join(name[:i])
                other = seen.setdefault(prefix.lower(), prefix)
                if other != prefix and f'{prefix}|{other}' not in seen:
                    seen[f'{prefix}|{other}'] = 1
                    problems.append(f'({prefix}) and ({other}) differ only by case: one directory on Windows and macOS')
    for p in problems:
        print(p)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
