#!/usr/bin/env python3
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
# Licensed under the MIT License.
"""Measure what the hip-fusion pass costs, for one or more crest-opt binaries.

Usage: run.py --crest-opt [LABEL=]PATH [--crest-opt ...] [--sizes N N ...] [--repeat R] [--check]

For each binary it times crest-opt on generated modules (generate-module.py) of several sizes (numbers of functions),
twice for each module:

  no pass     parse and print only
  with pass   the same with --crest-pass=passes=passes/hip-fusion

  start-up    the pass cost on an empty module: starting Chez and loading the libraries, paid once per run
  pass cost   with pass - no pass: start-up plus what the patterns cost on this module
  us/function the cost of one more function: the difference of the pass cost between this size and the one
              before it, divided by the difference of the sizes. The start-up cancels out, so it is the cost
              that matters when the module grows. (The first size is compared with the empty module.)

Two variants: "match" (every function fuses into one hip.qadd) and "no-match" (hip.sub, nothing fuses, so every
attempt fails). Every run with the pass is checked: the number of hip.qadd in the output must be the expected one,
or the numbers would be those of a failed run.

Times are CPU seconds (user + system) of the child process, the best of --repeat runs. The spread column is
(slowest - fastest) / fastest of the runs with the pass, so you can see whether the machine was quiet. MLIR threading
is off so that CPU time does not depend on the number of cores. Do not run this beside the test suite.

--check exits with 1 when us/function is not steady: the largest and the smallest value, leaving out the first size,
differ by more than 2.5 times. A cost that grows with the module (quadratic) shows up like this: the default sizes
make it about 4 times. The limit is wide on purpose, because the first measurement is a small difference of two big ones.
"""
import argparse
import importlib.util
import os
import pathlib
import platform
import resource
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent

# generate-module.py has a hyphen in its name, so it cannot be imported by name. No bytecode file is left beside it.
sys.dont_write_bytecode = True
_spec = importlib.util.spec_from_file_location("generate_module", HERE / "generate-module.py")
generate_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(generate_module)

PASS_OPTION = "--crest-pass=passes=passes/hip-fusion"
COMMON_OPTIONS = ["-allow-unregistered-dialect", "-mlir-disable-threading"]
STEADY_LIMIT = 2.5


class Result:
    def __init__(self, best, slowest, output):
        self.best = best
        self.slowest = slowest
        self.output = output

    @property
    def spread(self):
        return (self.slowest - self.best) / self.best if self.best > 0 else 0.0


def cpu_seconds_of_children():
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    return usage.ru_utime + usage.ru_stime


def run_once(tool, module, with_pass):
    command = [str(tool)] + COMMON_OPTIONS + ([PASS_OPTION] if with_pass else []) + [str(module)]
    environment = dict(os.environ, CREST_PATH=str(ROOT / "samples"))
    with tempfile.TemporaryFile() as output:
        before = cpu_seconds_of_children()
        completed = subprocess.run(command, env=environment, stdout=output, stderr=subprocess.PIPE)
        used = cpu_seconds_of_children() - before
        if completed.returncode != 0:
            sys.exit("%s failed (%d): %s" % (" ".join(command), completed.returncode, completed.stderr.decode()[:2000]))
        output.seek(0)
        return used, output.read()


def measure(tool, module, with_pass, repeat):
    times = []
    output = b""
    for _ in range(repeat):
        used, output = run_once(tool, module, with_pass)
        times.append(used)
    return Result(min(times), max(times), output)


def tool_version(tool):
    completed = subprocess.run([str(tool), "--version"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    for line in completed.stdout.decode().splitlines():
        if "LLVM version" in line:
            return line.strip()
    return "LLVM version unknown"


def parse_tool(text):
    label, separator, path = text.partition("=")
    if not separator:
        path = text
        label = pathlib.Path(path).resolve().parent.parent.parent.name
    if not pathlib.Path(path).is_file():
        sys.exit("not a file: " + path)
    return label, pathlib.Path(path)


def benchmark_tool(label, tool, sizes, repeat, out):
    """Print the table of one binary; answer the variants whose us/function is not steady."""
    out("")
    out("== %s: %s" % (label, tool))
    out("   %s" % tool_version(tool))

    unsteady = []
    with tempfile.TemporaryDirectory() as directory:
        empty = pathlib.Path(directory) / "empty.mlir"
        empty.write_text(generate_module.generate(0))
        startup = measure(tool, empty, True, repeat).best - measure(tool, empty, False, repeat).best
        out("   start-up (Chez and libraries), CPU s: %.3f" % startup)
        out("")
        out("   %-9s %9s %9s %10s %11s %10s %12s %9s %7s" % (
            "variant", "functions", "ops", "no pass s", "with pass s", "pass cost", "us/function", "us/op", "spread"))

        for variant, match in (("match", True), ("no-match", False)):
            previous_size, previous_cost = 0, startup
            marginals = []
            for size in sizes:
                module = pathlib.Path(directory) / ("%s-%d.mlir" % (variant, size))
                module.write_text(generate_module.generate(size, match=match))
                plain = measure(tool, module, False, repeat)
                fused = measure(tool, module, True, repeat)
                expected = size if match else 0
                found = fused.output.count(b'"hip.qadd"')
                if found != expected:
                    sys.exit("%s %s %d: %d hip.qadd in the output, expected %d" % (label, variant, size, found, expected))
                cost = fused.best - plain.best
                marginal = (cost - previous_cost) / (size - previous_size) * 1e6
                marginals.append(marginal)
                out("   %-9s %9d %9d %10.3f %11.3f %10.3f %12.1f %9.2f %6.0f%%" % (
                    variant, size, size * generate_module.OPS_PER_FUNCTION, plain.best, fused.best, cost, marginal,
                    marginal / generate_module.OPS_PER_FUNCTION, fused.spread * 100))
                previous_size, previous_cost = size, cost
            steady = marginals[1:]
            if len(steady) >= 2 and (min(steady) <= 0 or max(steady) / min(steady) > STEADY_LIMIT):
                unsteady.append("%s %s" % (label, variant))
    return unsteady


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--crest-opt", action="append", required=True, metavar="[LABEL=]PATH",
                        help="a crest-opt binary; repeat for several (for example dev and boot)")
    parser.add_argument("--sizes", type=int, nargs="+", default=[2000, 8000, 32000],
                        help="numbers of functions, increasing (default: 2000 8000 32000)")
    parser.add_argument("--repeat", type=int, default=5, help="runs per measurement; the best is used (default 5)")
    parser.add_argument("--check", action="store_true", help="exit 1 if us/function is not steady")
    args = parser.parse_args()
    if args.sizes != sorted(set(args.sizes)) or args.sizes[0] <= 0:
        parser.error("--sizes must be increasing positive numbers")

    def out(text):
        print(text, flush=True)

    out("CREST benchmark, %s" % time.strftime("%Y-%m-%d"))
    out("machine: %s, %d CPUs, load average at start %s" % (
        platform.platform(), os.cpu_count(), " ".join("%.1f" % load for load in os.getloadavg())))
    out("one function = %d operations; CPU seconds, best of %d; sizes %s" % (
        generate_module.OPS_PER_FUNCTION, args.repeat, args.sizes))

    unsteady = []
    for text in args.crest_opt:
        label, tool = parse_tool(text)
        unsteady += benchmark_tool(label, tool, args.sizes, args.repeat, out)

    out("")
    out("load average at end %s" % " ".join("%.1f" % load for load in os.getloadavg()))
    if len(args.sizes) < 3:
        out("steady check skipped: it needs at least 3 sizes")
    elif unsteady:
        out("NOT STEADY (us/function differs by more than %.1f times between sizes): %s" % (
            STEADY_LIMIT, ", ".join(unsteady)))
        if args.check:
            sys.exit(1)
    else:
        out("steady: us/function stays within %.1f times across the sizes" % STEADY_LIMIT)


if __name__ == "__main__":
    main()
