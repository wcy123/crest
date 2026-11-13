#!/usr/bin/env python3
"""tools/check-valgrind-logs.py fails on a leak and on a use after free, and passes a clean run.

Usage: check-valgrind-gate.py <repo root>

It is run on logs that this script writes (no valgrind is needed), shaped like the logs of valgrind --leak-check=full.
"""
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path(sys.argv[1]).resolve()
checker = root / "tools/check-valgrind-logs.py"

CLEAN = """==1== Command: /build/tools/crest-opt/crest-opt /test/ok.mlir
==1== LEAK SUMMARY:
==1==    definitely lost: 0 bytes in 0 blocks
"""
LEAK = """==2== Command: /build/tools/crest-opt/crest-opt /test/leaks.mlir
==2== 96 bytes in 1 blocks are definitely lost in loss record 1 of 1
==2== LEAK SUMMARY:
==2==    definitely lost: 96 bytes in 1 blocks
"""
USE_AFTER_FREE = """==3== Command: /build/tools/crest-opt/crest-opt /test/freed.mlir
==3== Invalid read of size 8
==3== LEAK SUMMARY:
==3==    definitely lost: 0 bytes in 0 blocks
"""
ENDS_THE_PROCESS_AND_LEAKS = """==4== Command: /build/tools/scheme-mlir/scheme-mlir /w/test/dsl/c-callable-results/driver.sls void
==4== LEAK SUMMARY:
==4==    definitely lost: 96 bytes in 1 blocks
"""
ENDS_THE_PROCESS_AND_FREED = """==5== Command: /build/tools/scheme-mlir/scheme-mlir /w/test/dsl/c-callable-results/driver.sls void
==5== Invalid read of size 8
==5== LEAK SUMMARY:
==5==    definitely lost: 96 bytes in 1 blocks
"""
CHEZ_ONLY = """==6== Command: /build/tools/crest-opt/crest-opt /test/chez.mlir
==6== Conditional jump or move depends on uninitialised value(s)
==6==    at 0x76387E1: ???
==6== LEAK SUMMARY:
==6==    definitely lost: 0 bytes in 0 blocks
"""


def run(*logs):
    with tempfile.TemporaryDirectory() as directory:
        for number, text in enumerate(logs):
            pathlib.Path(directory, f"crest-opt.{number}.log").write_text(text)
        return subprocess.run([sys.executable, str(checker), directory], capture_output=True, text=True)


problems = []
for name, logs, should_fail in (
    ("a clean run", [CLEAN], False),
    ("a leak", [CLEAN, LEAK], True),
    ("a use after free", [USE_AFTER_FREE], True),
    ("a run that ends the process on purpose and loses memory", [ENDS_THE_PROCESS_AND_LEAKS], False),
    ("a run that ends the process and reads freed memory", [ENDS_THE_PROCESS_AND_FREED], True),
    ("a report that is all Chez-generated code", [CHEZ_ONLY], False),
):
    result = run(*logs)
    if (result.returncode != 0) != should_fail:
        problems.append(f"{name}: expected {'a failure' if should_fail else 'a pass'}, got exit {result.returncode}: {result.stdout.strip()}")
if run().returncode == 0:
    problems.append("no logs at all must be a failure (lit was not run with the parameter)")
if problems:
    print("\n".join(problems))
    sys.exit(1)
