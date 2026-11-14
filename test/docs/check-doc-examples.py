#!/usr/bin/env python3
"""The examples in the docs must work when a reader copies them.

Usage: check-doc-examples.py <repo root> <crest-opt>

1. Every --crest-pass="..." in a doc uses only the options that CrestPass declares.
2. The tutorial: each step is built into a library, run on its input, and gives the output the doc shows.
3. The commands of the README that name files of the repository are run, and must succeed.
"""
import os
import pathlib
import re
import subprocess
import sys
import tempfile

root = pathlib.Path(sys.argv[1]).resolve()
crest_opt = sys.argv[2]
problems = []


def blocks(text):
    """Fenced blocks of a markdown text: (language, body, the 8 lines before the fence)."""
    lines = text.split("\n")
    result = []
    i = 0
    while i < len(lines):
        if lines[i].startswith("```"):
            language = lines[i][3:].strip()
            j = i + 1
            while j < len(lines) and not lines[j].startswith("```"):
                j += 1
            result.append((language, "\n".join(lines[i + 1:j]), "\n".join(lines[max(0, i - 8):i])))
            i = j
        i += 1
    return result


docs = [root / "README.md"] + sorted((root / "docs").glob("*.md")) + sorted((root / "samples").glob("**/README.md"))

# 1. The options of --crest-pass.
declared = set(re.findall(r'(?:List)?Option<[^>]*>\s+\w+\{\s*\*this,\s*"([^"]+)"',
                          (root / "lib/Passes/CrestPass.cpp").read_text(encoding="utf-8")))
if not declared:
    problems.append("lib/Passes/CrestPass.cpp: found no options (the check needs updating)")
for doc in docs:
    for match in re.finditer(r'--crest-pass="?([^"\s\\]+(?:[ ][^"\\\n]*)?)"?', doc.read_text(encoding="utf-8")):
        for token in match.group(1).split():
            key = token.split("=")[0]
            if "=" in token and key not in declared:
                problems.append(f"{doc.relative_to(root)}: --crest-pass has no option '{key}' "
                                f"(options: {', '.join(sorted(declared))})")


# 2. The tutorial.
def run(directory, library, input_file):
    env = dict(os.environ, CREST_PATH=str(directory), CREST_SCHEME_BINARY_DIR=str(directory / "bin"))
    return subprocess.run([crest_opt, "-allow-unregistered-dialect", f"--crest-pass=passes={library}", str(input_file)],
                          env=env, capture_output=True, text=True, encoding="utf-8")


tutorial = (root / "docs/tutorial.md").read_text(encoding="utf-8")
found = blocks(tutorial)
libraries = [b for l, b, _ in found if l == "scheme" and b.startswith("#!r6rs")]
patterns = {}
for l, b, _ in found:
    m = re.match(r"\(define-rewrite-pattern \((step\d+) ", b)
    if l == "scheme" and m:
        patterns[m.group(1)] = b
mlir_inputs = [b for l, b, _ in found if l == "mlir" and "source.add" in b]
mlir_outputs = [b for l, b, before in found if l == "mlir" and "target.fused" in b and "Output" in before]
if len(libraries) < 1 or "(define-rewrite-pattern (step1" not in libraries[0] or sorted(patterns) != ["step2", "step3"]:
    problems.append("docs/tutorial.md: expected a #!r6rs library with the pattern step1, and a block each for step2 and step3")
else:
    library = libraries[0]
    start = library.index("(define-rewrite-pattern (step1")
    end = library.index("(define-pass-entry-point")
    patterns["step1"] = library[start:end].rstrip()
    with tempfile.TemporaryDirectory() as tmp:
        directory = pathlib.Path(tmp)
        (directory / "passes").mkdir()
        for step in ("step1", "step2", "step3"):
            text = library[:start] + patterns[step] + "\n\n  " + library[end:]
            text = text.replace("tutorial-step1", f"tutorial-{step}").replace("step1", step)
            (directory / "passes" / f"tutorial-{step}.sls").write_text(text, encoding="utf-8")
        inputs = {"step1": mlir_inputs[0], "step2": mlir_inputs[0], "step3": mlir_inputs[-1]}
        for step in ("step1", "step2", "step3"):
            input_file = directory / f"{step}.mlir"
            input_file.write_text(inputs[step], encoding="utf-8")
            result = run(directory, f"passes/tutorial-{step}", input_file)
            if result.returncode != 0:
                problems.append(f"docs/tutorial.md: {step} fails: {(result.stdout + result.stderr).strip()[:300]}")
                continue
            if "target.fused" not in result.stdout:
                problems.append(f"docs/tutorial.md: {step} does not rewrite its input")
            if step == "step1" and mlir_outputs:
                actual = {" ".join(l.split()) for l in result.stdout.split("\n")}
                for line in mlir_outputs[0].split("\n"):
                    if " ".join(line.split()) not in actual:
                        problems.append(f"docs/tutorial.md: the output of step 1 shows a line that crest-opt does not print: {line.strip()}")
            if step == "step3" and "source.add" in result.stdout:
                problems.append("docs/tutorial.md: step 3 leaves a source.add (the 2- and the 3-operand form both match)")

# 3. The commands of the README.
text = (root / "README.md").read_text(encoding="utf-8")
for language, body, _ in blocks(text):
    if language != "bash" or "crest-opt" not in body:
        continue
    command = body.replace("\\\n", " ")
    files = re.findall(r"[\w/.\-]+\.mlir", command)
    if not files or not all((root / f).exists() for f in files):
        continue
    command = command.replace("build/tools/crest-opt/crest-opt", crest_opt)
    with tempfile.TemporaryDirectory() as binary_dir:
        result = subprocess.run(command, shell=True, cwd=root, capture_output=True, text=True, encoding="utf-8",
                                env=dict(os.environ, CREST_SCHEME_BINARY_DIR=binary_dir))
    if result.returncode != 0 or not result.stdout.strip():
        problems.append(f"README.md: this command fails: {' '.join(command.split())}\n    {(result.stdout + result.stderr).strip()[:300]}")

if problems:
    print("\n".join(problems))
    sys.exit(1)
