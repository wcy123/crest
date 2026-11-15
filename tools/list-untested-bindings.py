#!/usr/bin/env python3
"""List the bindings that no test, sample or doc of CREST reaches.

Usage: list-untested-bindings.py [repo root]

A binding is a key that lib/Bindings registers (Sregister_symbol or register_builder_binding). Scheme names it in an
ffi.sls (`(define %name (crest-foreign-procedure "key" ...))`), re-exports it from the public library, and a macro may wrap
that. A binding is reached when a name that a .sls, .sps, .mlir or .md file of test/, samples/ or docs/ mentions leads to
it: the mentioned name is defined in a library of scheme/, and its definition (the macro or the procedure) refers to the
name of the next definition, down to the one that holds the key. It is a text search: a name that a macro builds is not
seen, and a name that is only mentioned counts. It says where a test is missing, not whether the binding works.

Prints the bindings that are not reached, grouped by the C++ file, then a count.
"""
import collections
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()


def tokens(text):
    """The atoms of Scheme text, without comments (strings are kept whole)."""
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == ";":
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("#|", i):
            depth, i = 1, i + 2
            while i < n and depth:
                if text.startswith("|#", i):
                    depth, i = depth - 1, i + 2
                elif text.startswith("#|", i):
                    depth, i = depth + 1, i + 2
                else:
                    i += 1
        elif c in " \t\r\n":
            i += 1
        elif c in "()[]":
            yield c
            i += 1
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            yield text[i:j + 1]
            i = j + 1
        elif text.startswith("#\\", i):
            j = i + 3
            while j < n and text[j] not in " \t\r\n()[]":
                j += 1
            i = j
        else:
            j = i
            while j < n and text[j] not in ' \t\r\n()[]";':
                j += 1
            yield text[i:j]
            i = j


def top_forms(text):
    """The forms at depth 2 or 1 of a library: (define ...), (define-syntax ...), as lists of atoms."""
    depth, form, forms = 0, [], []
    for token in tokens(text):
        if token in "([":
            depth += 1
            if depth >= 3:
                form.append(token)
        elif token in ")]":
            if depth >= 3:
                form.append(token)
            if depth == 2:
                forms.append(form)
                form = []
            depth -= 1
        elif depth >= 2:
            form.append(token)
    return forms


registered = collections.defaultdict(list)
for path in sorted((root / "lib/Bindings").glob("**/*.cpp")):
    for match in re.finditer(r'(?:Sregister_symbol|register_builder_binding)\(\s*"([^"]+)"', path.read_text()):
        registered[match.group(1)].append(str(path.relative_to(root)))

# Definitions of the libraries: the name defined -> the names that its definition refers to; and the keys that it holds.
refers = collections.defaultdict(set)
holds = collections.defaultdict(set)
for path in (root / "scheme").glob("**/*.sls"):
    for form in top_forms(path.read_text()):
        if not form or form[0] not in ("define", "define-syntax", "define-builder-binding", "define-ctx-optional"):
            continue
        if form[0] == "define-builder-binding":
            names = [form[1]] if len(form) > 1 else []
        else:
            names = [form[1]] if len(form) > 1 and form[1] not in "([" else [form[2]] if len(form) > 2 else []
        for name in names:
            for atom in form[1:]:
                if atom.startswith('"'):
                    holds[name].add(atom[1:-1])
                elif atom not in "()[]":
                    refers[name].add(atom)

# What the tests, samples and docs mention.
mentioned = set()
for pattern in ("test/**/*.sls", "test/**/*.sps", "test/**/*.mlir", "samples/**/*.sls", "samples/**/*.md", "docs/*.md"):
    for path in root.glob(pattern):
        if path.is_file():
            mentioned |= {t for t in tokens(path.read_text(errors="replace"))} | set(
                re.findall(r"[\w:<>?!*%/.-]+", path.read_text(errors="replace")))

reached, work = set(), [name for name in mentioned if name in refers or name in holds]
while work:
    name = work.pop()
    if name in reached:
        continue
    reached.add(name)
    work += [other for other in refers.get(name, ()) if other not in reached and (other in refers or other in holds)]
keys_reached = set()
for name in reached:
    keys_reached |= holds.get(name, set())
# A key that a test names itself (a probe that uses the raw key) is reached too.
keys_reached |= {key for key in registered if key in mentioned}

# Keys that no Scheme library names at all: registered in C++ and never callable.
named = set()
for keys in holds.values():
    named |= keys
named |= {m for path in (root / "scheme").glob("**/*.sls") for m in re.findall(r'"([^"]+)"', path.read_text())}
orphans = sorted(key for key in registered if key not in named
                 and not any(key + suffix in named for suffix in ("<OpBuilder>", "<RewriterBase*>", "<OpBuilder*>")))

unreached = collections.defaultdict(list)
for key, files in sorted(registered.items()):
    if key in orphans or key in keys_reached:
        continue
    unreached[files[0]].append(key)
total = sum(len(v) for v in unreached.values())
for file, keys in sorted(unreached.items()):
    print(f"{file}:")
    for key in keys:
        print(f"  {key}")
print(f"{total} of {len(registered)} bindings are named by Scheme but not reached by any test, sample or doc")
if orphans:
    print("\nRegistered in C++, named by no Scheme library (never callable):")
    for key in orphans:
        print(f"  {key}  ({registered[key][0]})")
