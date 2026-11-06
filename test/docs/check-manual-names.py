#!/usr/bin/env python3
"""Check that the names docs/manual.md lists exist in the Scheme libraries.

Section 9 tables name a library and the exports to import from it; the "CREST public API"
paragraph names what (crest) exports; and any other `mlir::A::b` or `crest::A::b` name in the
manual must be exported by some library. Exits 1 and lists every name that is not.
"""
import os
import re
import sys


def tokens(text):
    out, i = [], 0
    while i < len(text):
        c = text[i]
        if c == ';':
            while i < len(text) and text[i] != '\n':
                i += 1
        elif c == '"':
            i += 1
            while text[i] != '"':
                i += 2 if text[i] == '\\' else 1
            i += 1
        elif c == '#' and text[i + 1] == '\\':
            i += 3
        elif c in '()[]':
            out.append(c)
            i += 1
        elif c.isspace():
            i += 1
        else:
            j = i
            while j < len(text) and not text[j].isspace() and text[j] not in '()[];"':
                j += 1
            out.append(text[i:j])
            i = j
    return out


def read_forms(toks, i):
    """Read one form starting at toks[i]; return (form, next index)."""
    if toks[i] in '([':
        form, i = [], i + 1
        while toks[i] not in ')]':
            sub, i = read_forms(toks, i)
            form.append(sub)
        return form, i + 1
    return toks[i], i + 1


def library_exports(root):
    libs = {}
    for dirpath, _, files in os.walk(root):
        for f in files:
            if not f.endswith('.sls'):
                continue
            toks = tokens(open(os.path.join(dirpath, f), encoding='utf-8').read())
            try:
                at = toks.index('library')
                name, j = read_forms(toks, at + 1)
                exports = set()
                k = j
                while k < len(toks) and not (toks[k] == 'export' and toks[k - 1] == '('):
                    k += 1
                depth, k = 1, k + 1
                while depth:
                    if toks[k] in '([':
                        depth += 1
                    elif toks[k] in ')]':
                        depth -= 1
                    else:
                        exports.add(toks[k])
                    k += 1
                libs[' '.join(name)] = exports
            except (ValueError, IndexError):
                continue
    return libs


def main(manual_path, scheme_root):
    libs = library_exports(scheme_root)
    everything = set().union(*libs.values())
    manual = open(manual_path, encoding='utf-8').read()
    problems = []

    section = manual[manual.index('## 9. MLIR bindings reference'):manual.index('## 10. Deployment')]
    for row in re.finditer(r'^\| `\((mlir [^)]*)\)` \| (.*) \|$', section, re.M):
        lib = row.group(1)
        if lib not in libs:
            problems.append(f'library ({lib}) does not exist')
            continue
        prefix = None
        for item in re.findall(r'`([^`]+)`', row.group(2)):
            if '::' in item:
                prefix = item.rsplit('::', 1)[0] + '::'
                full = item
            elif prefix and re.fullmatch(r'[A-Za-z!?<>*+%.]+|operator[-+*%]', item):
                full = prefix + item
            else:
                full = item
            if full not in libs[lib]:
                problems.append(f'({lib}) does not export {full}')

    api = manual[manual.index('### CREST public API'):manual.index('## 10. Deployment')]
    api = api[api.index('Exports:'):api.index('`add-rewrite-pattern`, `add-conversion-pattern`')]
    for span in re.findall(r'`([^`]+)`', api):
        for item in span.split():
            if item not in libs['crest']:
                problems.append(f'(crest) does not export {item}')

    cxx_classes = {'mlir::OpRewritePattern', 'mlir::ConversionPattern', 'mlir::Value*',
                   'mlir::OpBuilder', 'mlir::Type', 'mlir::Attribute', 'mlir::Location',
                   'mlir::Operation', 'mlir::Value', 'mlir::Block', 'mlir::Region'}
    for name in sorted(set(re.findall(r'`((?:mlir|crest)::[A-Za-z0-9_:<>!?/*,.-]+)`', manual))):
        if name in cxx_classes or name in everything:
            continue
        if name.count('::') >= 2 or '<' in name:
            problems.append(f'no library exports {name}')

    if problems:
        print('manual names that do not exist:')
        for p in sorted(set(problems)):
            print('  ' + p)
        return 1
    print('all manual names exist')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2]))
