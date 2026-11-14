#!/usr/bin/env python3
"""The manual says which handles end with their scope, because nothing in C++ can tell.

Usage: check-doc-lifetimes.py <manual>

A handle is an address. A pass manager that `nest` answers, a pass that `addPass` took, and a type converter that a
conversion pattern points at all stop being valid when their owner ends, and a use after that is not an error that
CREST can report. The manual has a "Lifetimes" section that names each of them.
"""
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
section = re.search(r"^### Lifetimes$(.*?)^#{2,3} ", text, re.M | re.S)
if not section:
    print('docs/manual.md: no "### Lifetimes" section')
    sys.exit(1)
body = section.group(1)
problems = [f"docs/manual.md: the Lifetimes section does not mention {name}"
            for name in ("with-PassManager", "mlir::PassManager::nest", "addPass", "with-TypeConverter",
                         "with-ConversionTarget")
            if name not in body]
if problems:
    print("\n".join(problems))
    sys.exit(1)
