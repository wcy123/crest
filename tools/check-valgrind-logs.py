#!/usr/bin/env python3
"""Read the logs of lit --param valgrind_logs=DIR and fail when a run lost memory or used it wrongly.

Usage: check-valgrind-logs.py DIR

A log is a run of crest-opt or scheme-mlir. It is a problem when it has "definitely lost" bytes (a leak), an invalid read
or write (a use after free), or a free of the wrong kind. The log says which command ran (its "Command:" line), and so
which test.
"""
import pathlib
import re
import sys

logs = sorted(pathlib.Path(sys.argv[1]).glob("*.log"))
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
    found = [label for pattern, label in kinds if pattern.search(text)]
    if found:
        problems += 1
        print(f"{log.name}: {', '.join(found)}\n    {command.group(1)[:200] if command else '(no command line)'}")
print(f"{len(logs)} runs, {problems} with a problem")
sys.exit(1 if problems else 0)
