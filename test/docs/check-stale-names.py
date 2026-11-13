#!/usr/bin/env python3
"""Check that the docs name no API that CREST has removed.

Fails on `register_binding` (bindings use Sregister_symbol, CLAUDE.md Rule 4) and on the old
hyphenated Scheme names (`mlir-value-get-type`, ...). A hyphenated `mlir-...` name in a code span
or code block must be a tool or flag (listed below) or a name that Scheme code under the given roots uses.
"""
import os
import re
import sys

NOT_SCHEME_NAMES = {
    'mlir-opt', 'mlir-tblgen', 'mlir-pdll', 'mlir-translate', 'mlir-22-tools',
    'mlir-print-ir-after-all', 'mlir-print-debuginfo', 'mlir-disable-threading', 'mlir-opt-style',
}
REMOVED = ['register_binding']


def code_text(markdown):
    spans = re.findall(r'```.*?```', markdown, re.S)
    rest = re.sub(r'```.*?```', '', markdown, flags=re.S)
    return '\n'.join(spans + re.findall(r'`([^`\n]+)`', rest))


def main(root, scheme_roots):
    exported = set()
    for scheme_root in scheme_roots:
        for dirpath, _, files in os.walk(scheme_root):
            for f in files:
                if f.endswith('.sls'):
                    code = re.sub(r';[^\n]*', '', open(os.path.join(dirpath, f), encoding='utf-8').read())
                    exported.update(re.findall(r'(?<![\w-])mlir-[a-z0-9-]+', code))
    docs = [os.path.join(root, 'README.md')]
    for dirpath, _, files in os.walk(os.path.join(root, 'docs')):
        docs += [os.path.join(dirpath, f) for f in files if f.endswith('.md')]
    problems = []
    for path in sorted(docs):
        text = open(path, encoding='utf-8').read()
        code = code_text(text)
        for name in REMOVED:
            if name in text:
                problems.append(f'{os.path.relpath(path, root)}: mentions removed {name}')
        for name in sorted(set(re.findall(r'(?<![\w#/.-])mlir-[a-z0-9]+(?:-[a-z0-9]+)+', code))):
            if name not in NOT_SCHEME_NAMES and name not in exported:
                problems.append(f'{os.path.relpath(path, root)}: {name} is not a name CREST exports')
    for p in problems:
        print(p)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2:]))
