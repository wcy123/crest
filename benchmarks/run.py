#!/usr/bin/env python3
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
# Licensed under the MIT License.
"""Measure what the hip-fusion pass costs, for one or more crest-opt binaries, and compare it with C++.

Usage: run.py --crest-opt [LABEL=]PATH [--crest-opt ...] [--cpp-opt [LABEL=]PATH] [--instructions]
              [--sizes N N ...] [--repeat R] [--check]

Each crest-opt binary is measured with two passes: "hip-fusion" (the real pass, 15 patterns) and "qadd only" (benchmarks/passes/
qadd-only.sls: one pattern, the qadd fusion of samples/passes/hip-fusion/qadd.sls). The --cpp-opt binary (crest-bench-cpp, built with
-DCREST_BUILD_BENCHMARKS=ON) has that one pattern written in C++, so "qadd only" against "C++" compares one pattern with one pattern.
Their outputs must be equal, or the run stops: a comparison of two different results would mean nothing.

Each of them is run on generated modules (generate-module.py) of several sizes (numbers of functions), twice for each module:

  no pass     parse and print only
  with pass   the same with the pass

  start-up    the pass cost on an empty module: starting Chez and loading the libraries, paid once per run
  pass cost   with pass - no pass: start-up plus what the patterns cost on this module
  per function  the cost of one more function: the difference of the pass cost between this size and the one
              before it, divided by the difference of the sizes. The start-up cancels out, so it is the cost
              that matters when the module grows. (The first size is compared with the empty module.)

Two variants: "match" (every function fuses into one hip.qadd) and "no-match" (hip.sub, nothing fuses, so every
attempt fails). Every run with the pass is checked: the number of hip.qadd in the output must be the expected one,
or the numbers would be those of a failed run.

Two ways to measure:

  CPU time (default)  user + system seconds of the child process, the best of --repeat runs; the spread column is
                      (slowest - fastest) / fastest, so you can see whether the machine was quiet. This is what a user
                      sees, but it depends on the other work on the machine: do not run it beside the test suite.
  --instructions      the number of instructions the process executes, counted by valgrind's callgrind. It is the same
                      on every run and does not depend on the load of the machine, so one run is enough and the runs
                      go in parallel. It does not see cache misses, which CPU time does. The default sizes are smaller,
                      as callgrind is about 30 times slower.

MLIR threading is off so that the numbers do not depend on the number of cores.

--check exits with 1 when the cost per function is not steady: the largest and the smallest value, leaving out the first size,
differ by more than 3 times. A cost that grows with the module (quadratic) shows up like this: the default sizes make
it about 4 times. The limit is wide on purpose: a big module also costs more per function in C++ (memory), and the first
measurement of the CPU time is a small difference of two big ones.
"""
import argparse
import concurrent.futures
import importlib.util
import os
import pathlib
import platform
import resource
import shutil
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

COMMON_OPTIONS = ["-allow-unregistered-dialect", "-mlir-disable-threading"]
FULL_PASS = ["--crest-pass=passes=passes/hip-fusion"]
QADD_PASS = ["--crest-pass=passes=passes/qadd-only"]
CPP_PASS = ["--bench-qadd-fusion"]
STEADY_LIMIT = 3.0

VARIANTS = (("match", True), ("no-match", False))


class Result:
    def __init__(self, best, slowest, output):
        self.best = best
        self.slowest = slowest
        self.output = output

    @property
    def spread(self):
        return (self.slowest - self.best) / self.best if self.best > 0 else 0.0


def command_for(tool, options, module):
    return [str(tool)] + COMMON_OPTIONS + options + [str(module)]


def environment():
    return dict(os.environ, CREST_PATH=os.pathsep.join([str(ROOT / "samples"), str(ROOT / "benchmarks")]))


def fail_run(command, completed):
    sys.exit("%s failed (%d): %s" % (" ".join(command), completed.returncode, completed.stderr.decode()[:2000]))


def cpu_seconds_of_children():
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    return usage.ru_utime + usage.ru_stime


class CpuTime:
    parallel = False
    default_sizes = [2000, 8000, 32000]
    total_unit = "s"
    function_unit = "us/function"
    operation_unit = "us/op"

    def measure(self, tool, options, module, repeat):
        command = command_for(tool, options, module)
        times = []
        output = b""
        for _ in range(repeat):
            with tempfile.TemporaryFile() as stdout:
                before = cpu_seconds_of_children()
                completed = subprocess.run(command, env=environment(), stdout=stdout, stderr=subprocess.PIPE)
                used = cpu_seconds_of_children() - before
                if completed.returncode != 0:
                    fail_run(command, completed)
                stdout.seek(0)
                output = stdout.read()
            times.append(used)
        return Result(min(times), max(times), output)

    def total(self, value):
        return "%.3f" % value

    def per_function(self, value, size):
        return value / size * 1e6

    def startup(self, value):
        return "%.3f s" % value


class Instructions:
    parallel = True
    default_sizes = [1000, 4000]
    total_unit = "M"
    function_unit = "kinstr/function"
    operation_unit = "kinstr/op"

    def __init__(self):
        if not shutil.which("valgrind"):
            sys.exit("--instructions needs valgrind (callgrind), which is not on the PATH")

    def measure(self, tool, options, module, repeat):
        command = command_for(tool, options, module)
        with tempfile.TemporaryDirectory() as directory:
            callgrind_out = pathlib.Path(directory) / "callgrind.out"
            wrapped = ["valgrind", "--tool=callgrind", "--callgrind-out-file=%s" % callgrind_out] + command
            with tempfile.TemporaryFile() as stdout:
                completed = subprocess.run(wrapped, env=environment(), stdout=stdout, stderr=subprocess.PIPE)
                if completed.returncode != 0:
                    fail_run(wrapped, completed)
                stdout.seek(0)
                output = stdout.read()
            for line in callgrind_out.read_text().splitlines():
                if line.startswith("totals:"):
                    count = float(line.split()[1])
                    return Result(count, count, output)
        sys.exit("no totals line in the callgrind output of " + " ".join(command))

    def total(self, value):
        return "%.1f" % (value / 1e6)

    def per_function(self, value, size):
        return value / size / 1e3

    def startup(self, value):
        return "%.1f M instructions" % (value / 1e6)


class Contestant:
    """One tool with one pass. Contestants of the same `group` must print the same output."""

    def __init__(self, label, tool, pass_options, group, is_baseline=False):
        self.label = label
        self.tool = tool
        self.pass_options = pass_options
        self.group = group
        self.is_baseline = is_baseline
        self.startup = 0.0
        self.rows = {name: [] for name, _ in VARIANTS}


def tool_version(tool):
    completed = subprocess.run([str(tool), "--version"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    for line in completed.stdout.decode().splitlines():
        if "LLVM version" in line:
            return line.strip()
    return "LLVM version unknown"


def parse_tool(text, default_label=None):
    label, separator, path = text.partition("=")
    if not separator:
        path = text
        label = default_label or pathlib.Path(path).resolve().parent.parent.parent.name
    if not pathlib.Path(path).is_file():
        sys.exit("not a file: " + path)
    return label, pathlib.Path(path)


def first_difference(left, right):
    for number, (a, b) in enumerate(zip(left.splitlines(), right.splitlines()), 1):
        if a != b:
            return "line %d: %r against %r" % (number, a.decode(errors="replace"), b.decode(errors="replace"))
    return "one output is longer (%d and %d lines)" % (len(left.splitlines()), len(right.splitlines()))


def benchmark(contestants, sizes, repeat, directory, metric):
    """Fill the rows of every contestant. Stops when a run is wrong or when two outputs that must be equal are not."""
    directory = pathlib.Path(directory)
    empty = directory / "empty.mlir"
    empty.write_text(generate_module.generate(0))
    modules = {}
    for variant, match in VARIANTS:
        for size in sizes:
            modules[(variant, size)] = directory / ("%s-%d.mlir" % (variant, size))
            modules[(variant, size)].write_text(generate_module.generate(size, match=match))

    results = {}

    def get(tool, options, module):
        key = (str(tool), tuple(options), str(module))
        if key not in results:
            results[key] = metric.measure(tool, options, module, repeat)
        return results[key]

    if metric.parallel:
        wanted = {}
        for contestant in contestants:
            for module in [empty] + list(modules.values()):
                for options in (contestant.pass_options, []):
                    wanted[(str(contestant.tool), tuple(options), str(module))] = (contestant.tool, options, module)
        workers = max(1, (os.cpu_count() or 2) // 2)
        print("   %d runs of valgrind, %d at a time ..." % (len(wanted), workers), file=sys.stderr, flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
            for key, result in zip(wanted, pool.map(lambda job: metric.measure(*job, repeat), wanted.values())):
                results[key] = result

    for contestant in contestants:
        contestant.startup = (get(contestant.tool, contestant.pass_options, empty).best
                              - get(contestant.tool, [], empty).best)

    for variant, match in VARIANTS:
        previous = {contestant: (0, contestant.startup) for contestant in contestants}
        for size in sizes:
            module = modules[(variant, size)]
            print("   measuring %s, %d functions ..." % (variant, size), file=sys.stderr, flush=True)
            outputs = {}
            for contestant in contestants:
                base = get(contestant.tool, [], module)
                with_pass = get(contestant.tool, contestant.pass_options, module)
                expected = size if match else 0
                found = with_pass.output.count(b'"hip.qadd"')
                if found != expected:
                    sys.exit("%s, %s, %d functions: %d hip.qadd in the output, expected %d" % (
                        contestant.label, variant, size, found, expected))
                if contestant.group in outputs:
                    other, other_output = outputs[contestant.group]
                    if other_output != with_pass.output:
                        sys.exit("%s and %s print different output for %s, %d functions: %s" % (
                            other, contestant.label, variant, size, first_difference(other_output, with_pass.output)))
                else:
                    outputs[contestant.group] = (contestant.label, with_pass.output)
                cost = with_pass.best - base.best
                last_size, last_cost = previous[contestant]
                marginal = (cost - last_cost) / (size - last_size)
                contestant.rows[variant].append((size, base.best, with_pass.best, cost, marginal, with_pass.spread))
                previous[contestant] = (size, cost)


def print_table(contestant, metric, out):
    unit = metric.total_unit
    out("")
    out("== %s: %s" % (contestant.label, contestant.tool))
    out("   %s" % tool_version(contestant.tool))
    out("   start-up: %s" % metric.startup(contestant.startup))
    out("")
    out("   %-9s %9s %9s %12s %12s %12s %16s %12s %7s" % (
        "variant", "functions", "ops", "no pass " + unit, "with pass " + unit, "pass cost " + unit,
        metric.function_unit, metric.operation_unit, "spread"))
    for variant, _ in VARIANTS:
        for size, plain, with_pass, cost, marginal, spread in contestant.rows[variant]:
            per_function = metric.per_function(marginal, 1)
            out("   %-9s %9d %9d %12s %12s %12s %16.1f %12.2f %6.0f%%" % (
                variant, size, size * generate_module.OPS_PER_FUNCTION, metric.total(plain), metric.total(with_pass),
                metric.total(cost), per_function, per_function / generate_module.OPS_PER_FUNCTION, spread * 100))


def unsteady_variants(contestant):
    unsteady = []
    for variant, _ in VARIANTS:
        steady = [row[4] for row in contestant.rows[variant]][1:]
        if len(steady) >= 2 and (min(steady) <= 0 or max(steady) / min(steady) > STEADY_LIMIT):
            unsteady.append("%s %s" % (contestant.label, variant))
    return unsteady


def print_comparison(contestants, metric, out):
    baseline = next((c for c in contestants if c.is_baseline), None)
    out("")
    out("== comparison: cost of one more function at the largest size (%s; lower is better)" % metric.function_unit)
    out("")
    columns = "   %-34s %18s %10s %10s" % ("", "start-up", "match", "no-match")
    if baseline:
        columns += " %14s %14s" % ("match / C++", "no-match / C++")
    out(columns)
    for contestant in contestants:
        costs = [metric.per_function(contestant.rows[variant][-1][4], 1) for variant, _ in VARIANTS]
        line = "   %-34s %18s %10.1f %10.1f" % (contestant.label, metric.startup(contestant.startup), costs[0], costs[1])
        if baseline:
            base_costs = [metric.per_function(baseline.rows[variant][-1][4], 1) for variant, _ in VARIANTS]
            line += " " + " ".join(
                "%14s" % ("%.2fx" % (cost / base) if base > 0 else "n/a") for cost, base in zip(costs, base_costs))
        out(line)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--crest-opt", action="append", required=True, metavar="[LABEL=]PATH",
                        help="a crest-opt binary; repeat for several (for example dev and boot)")
    parser.add_argument("--cpp-opt", metavar="[LABEL=]PATH",
                        help="crest-bench-cpp, the C++ version of the qadd fusion (cmake -DCREST_BUILD_BENCHMARKS=ON)")
    parser.add_argument("--instructions", action="store_true",
                        help="count instructions with valgrind instead of timing (exact, any load, slower)")
    parser.add_argument("--sizes", type=int, nargs="+",
                        help="numbers of functions, increasing (default: 2000 8000 32000; with --instructions 1000 4000)")
    parser.add_argument("--repeat", type=int, default=5,
                        help="runs per measurement; the best is used (default 5; one with --instructions)")
    parser.add_argument("--check", action="store_true", help="exit 1 if the cost per function is not steady")
    args = parser.parse_args()
    metric = Instructions() if args.instructions else CpuTime()
    sizes = args.sizes or metric.default_sizes
    if sizes != sorted(set(sizes)) or sizes[0] <= 0:
        parser.error("--sizes must be increasing positive numbers")
    repeat = 1 if args.instructions else args.repeat

    def out(text):
        print(text, flush=True)

    contestants = []
    for text in args.crest_opt:
        label, tool = parse_tool(text)
        contestants.append(Contestant("%s hip-fusion (15 patterns)" % label, tool, FULL_PASS, "full"))
        contestants.append(Contestant("%s qadd only (1 pattern)" % label, tool, QADD_PASS, "qadd"))
    if args.cpp_opt:
        label, tool = parse_tool(args.cpp_opt, "cpp")
        contestants.append(Contestant("%s C++ (1 pattern)" % label, tool, CPP_PASS, "qadd", is_baseline=True))

    out("CREST benchmark, %s" % time.strftime("%Y-%m-%d"))
    out("machine: %s, %d CPUs, load average at start %s" % (
        platform.platform(), os.cpu_count(), " ".join("%.1f" % load for load in os.getloadavg())))
    out("one function = %d operations; %s; sizes %s" % (
        generate_module.OPS_PER_FUNCTION,
        "instructions counted by callgrind" if args.instructions else "CPU seconds, best of %d" % repeat, sizes))

    with tempfile.TemporaryDirectory() as directory:
        benchmark(contestants, sizes, repeat, directory, metric)

    for contestant in contestants:
        print_table(contestant, metric, out)
    print_comparison(contestants, metric, out)

    unsteady = [name for contestant in contestants for name in unsteady_variants(contestant)]
    out("")
    out("load average at end %s" % " ".join("%.1f" % load for load in os.getloadavg()))
    if len(sizes) < 3:
        out("steady check skipped: it needs at least 3 sizes")
    elif unsteady:
        out("NOT STEADY (the cost per function differs by more than %.1f times between sizes): %s" % (
            STEADY_LIMIT, ", ".join(unsteady)))
        if args.check:
            sys.exit(1)
    else:
        out("steady: the cost per function stays within %.1f times across the sizes" % STEADY_LIMIT)


if __name__ == "__main__":
    main()
