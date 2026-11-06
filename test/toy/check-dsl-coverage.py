#!/usr/bin/env python3
"""Check that the Toy tutorials create ops with the DSL.

The tutorials teach CREST by example, so an op created by hand with an OperationState or a typed
builder (mlir::arith::AddFOp::create and the like) must be a deliberate exception. This lists every
such call under samples/toy and fails on any that is not in ALLOWED, with the reason.
"""
import os
import re
import sys

# (file name, pattern) -> why the DSL is not used there
ALLOWED = {
    ('toyc.sls', 'OperationState'):
        'the Scheme inliner clones ops whose name, operands and attributes are data '
        '(MLIR\'s inliner cannot run on a Scheme dialect before LLVM 23)',
    ('mlir-gen.sls', 'ModuleOp::create'):
        'creates the module that holds the generated functions, not an op the DSL builds',
}

PATTERNS = [
    ('OperationState', re.compile(r'with-OperationState|create<OperationState>|OperationState::add(Operands|Types|Attribute)\b')),
    ('typed create', re.compile(r'\bmlir::[A-Za-z0-9_:]+Op::create(?!d)\b|\bmlir::[A-Za-z0-9_:]+Op::create<')),
]


def main(root):
    problems = []
    for dirpath, _, files in os.walk(root):
        for name in sorted(files):
            if not name.endswith('.sls'):
                continue
            path = os.path.join(dirpath, name)
            with open(path, encoding='utf-8') as f:
                lines = f.read().split('\n')
            for number, line in enumerate(lines, 1):
                code = line.split(';', 1)[0]
                for label, pattern in PATTERNS:
                    if not pattern.search(code):
                        continue
                    key = 'ModuleOp::create' if 'ModuleOp::create' in code else label
                    if (name, key) in ALLOWED:
                        continue
                    problems.append(f'{os.path.relpath(path, root)}:{number}: {label}: {code.strip()}')
    if problems:
        print('ops created without the DSL in the Toy tutorials:')
        for p in problems:
            print('  ' + p)
        return 1
    print('every op in the Toy tutorials is created with the DSL, apart from the listed exceptions')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
