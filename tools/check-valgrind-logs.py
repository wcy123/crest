#!/usr/bin/env python3
"""Read the logs of lit --param valgrind_logs=DIR and fail when a run lost memory or used it wrongly.

Usage: check-valgrind-logs.py DIR

A log is a run of crest-opt or scheme-mlir. It is a problem when it has "definitely lost" bytes (a leak), an invalid read
or write (a use after free), or a free of the wrong kind. The log says which command ran (its "Command:" line), and so
which test. The runs in test/valgrind-ends-the-process.txt end the process on purpose before their scopes close; they may
lose memory.

Not looked for: "uninitialised value". Every report of it so far has a stack that is all Chez-generated code (no symbols),
which valgrind cannot follow, and none had a frame of CREST or LLVM.
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
logs = sorted(pathlib.Path(sys.argv[1]).glob("*.log"))
ends_the_process = [re.compile(line.strip())
                    for line in (root / "test/valgrind-ends-the-process.txt").read_text().split("\n")
                    if line.strip() and not line.startswith("#")]
if not logs:
    print(f"{sys.argv[1]}: no logs (was lit run with --param valgrind_logs=...?)")
    sys.exit(1)

kinds = [
    (re.compile(r"definitely lost: ([1-9][0-9,]*) bytes"), "definitely lost"),
    (re.compile(r"Invalid (read|write) of size"), "invalid read or write"),
    (re.compile(r"Mismatched free\(\) / delete / delete \[\]"), "mismatched free"),
    (re.compile(r"Invalid free\(\) / delete / delete\[\]"), "invalid free"),
]
problems = 0
for log in logs:
    text = log.read_text(errors="replace")
    command = re.search(r"Command: (.*)", text)
    excused = command and any(pattern.search(command.group(1)) for pattern in ends_the_process)
    found = [label for pattern, label in kinds
             if pattern.search(text) and not (excused and label == "definitely lost")]
    if found:
        problems += 1
        print(f"{log.name}: {', '.join(found)}\n    {command.group(1)[:200] if command else '(no command line)'}")
print(f"{len(logs)} runs, {problems} with a problem")
sys.exit(1 if problems else 0)
