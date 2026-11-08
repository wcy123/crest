#!/usr/bin/env python3
"""Check that mlir-gen in the Toy tutorials leaves out the result type where C++ Toy's builders do.

In C++ Toy, AddOp, MulOp, TransposeOp, ConstantOp and StructAccessOp have builders that work out the
result type, so MLIRGen.cpp names none for them. Here those ops implement InferTypeOpInterface, so an
op-form in mlir-gen.sls must not write `-> type` for them. The other ops (reshape, generic_call,
struct_constant) are built with an explicit type in C++ and keep it.
"""
import os
import re
import sys

INFERRED = ('add', 'mul', 'transpose', 'constant', 'struct_access')

OP_FORM = re.compile(r'\btoy\.(' + '|'.join(INFERRED) + r')\s+\(')
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


def main(root):
    problems = []
    checked = 0
    for chapter in sorted(os.listdir(root)):
        path = os.path.join(root, chapter, 'mlir-gen.sls')
        if not os.path.isfile(path):
            continue
        with open(path, encoding='utf-8') as f:
            text = f.read()
        # Keep the offsets: blank out the comments instead of removing them.
        text = re.sub(r';[^\n]*', lambda m: ' ' * len(m.group(0)), text)
        for match in OP_FORM.finditer(text):
            checked += 1
            span = text[match.start():op_form_end(text, match.start())]
            if ARROW.search(span):
                line = text.count('\n', 0, match.start()) + 1
                problems.append(f'{chapter}/mlir-gen.sls:{line}: toy.{match.group(1)} is created with '
                                f'-> type, but it implements InferTypeOpInterface')
    if checked == 0:
        print('no op-form of an inferred Toy op found in mlir-gen.sls: the check looks in the wrong place')
        return 1
    if problems:
        print('mlir-gen names a result type that the op infers:')
        for p in problems:
            print('  ' + p)
        return 1
    print(f'{checked} op-forms in mlir-gen.sls leave out the result type the op infers')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
