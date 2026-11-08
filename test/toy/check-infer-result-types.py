#!/usr/bin/env python3
"""Check that the Toy tutorials leave out the result type where C++ Toy's builders do.

mlir-gen (the default): in C++ Toy, AddOp, MulOp, TransposeOp, ConstantOp and StructAccessOp have
builders that work out the result type, so MLIRGen.cpp names none for them. Here those ops implement
InferTypeOpInterface, so an op-form in mlir-gen.sls must not write `-> type` for them. The other ops
(reshape, generic_call, struct_constant) are built with an explicit type in C++ and keep it.

lowering: LowerToAffineLoops.cpp creates arith::AddFOp and arith::MulFOp from their two operands, whose
result type they infer (SameOperandsAndResultType), so an op-form in lower-to-affine.sls must not write
`-> type` for arith.addf and arith.mulf. The other ops it creates take a type in C++ as well.

usage: check-infer-result-types.py <samples/toy> [mlir-gen|lowering]
"""
import os
import re
import sys

# mode -> (file in each chapter, op-form pattern)
MODES = {
    'mlir-gen': ('mlir-gen.sls',
                 re.compile(r'\b(toy\.(?:add|mul|transpose|constant|struct_access))\s+\(')),
    'lowering': ('lower-to-affine.sls',
                 re.compile(r'\b(arith\.(?:addf|mulf))\s+\(')),
}
ARROW = re.compile(r'(?<![\w>-])->(?![\w>-])')


def op_form_end(text, start):
    """Index of the parenthesis that closes the form which contains the op-form at `start`."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth < 0:
                return i
    return len(text)


def main(root, mode):
    name, op_form = MODES[mode]
    problems = []
    checked = 0
    for chapter in sorted(os.listdir(root)):
        path = os.path.join(root, chapter, name)
        if not os.path.isfile(path):
            continue
        with open(path, encoding='utf-8') as f:
            text = f.read()
        # Keep the offsets: blank out the comments instead of removing them.
        text = re.sub(r';[^\n]*', lambda m: ' ' * len(m.group(0)), text)
        for match in op_form.finditer(text):
            checked += 1
            span = text[match.start():op_form_end(text, match.start())]
            if ARROW.search(span):
                line = text.count('\n', 0, match.start()) + 1
                problems.append(f'{chapter}/{name}:{line}: {match.group(1)} is created with '
                                f'-> type, but it implements InferTypeOpInterface')
    if checked == 0:
        print(f'no op-form of an inferred op found in {name}: the check looks in the wrong place')
        return 1
    if problems:
        print(f'{name} names a result type that the op infers:')
        for p in problems:
            print('  ' + p)
        return 1
    print(f'{checked} op-forms in {name} leave out the result type the op infers')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else 'mlir-gen'))
