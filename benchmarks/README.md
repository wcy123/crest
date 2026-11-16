# Benchmarks

What the hip-fusion pass costs, measured on generated modules, and how that compares with the same fusion written in C++. It answers:

1. How long does `crest-opt` take to start with a CREST pass (Chez and the libraries), in development mode and in boot mode?
2. What does one more function cost, when its fusion matches and when it does not?
3. How many times the cost of a C++ pattern is that?
4. Does the cost stay the same when the module grows? A cost that grows faster than the module (quadratic) is what `--check` looks for.

The scripts need Linux and a built `crest-opt`. Nothing here is built by default, and the only part that `check-crest` runs is a smoke test
(`test/benchmarks`) on tiny modules.

## What is compared

- `hip-fusion`: the real pass of `samples/passes/hip-fusion.sls`, fifteen patterns.
- `qadd only`: the same, with only the first pattern (`benchmarks/passes/qadd-only.sls`, which imports the sample pattern unchanged).
- `C++`: `benchmarks/cpp/QAddFusion.cpp`, the same fusion written as a C++ `RewritePattern` in an `mlir-opt`-style tool (`crest-bench-cpp`).

`qadd only` against `C++` is one pattern against one pattern. The two must print the same output; the run stops when they do not. Because both
use the same parser, printer and greedy driver, the difference between them is the cost of the pattern and of Scheme, nothing else.

## Run it

Build the C++ side once (`-DCREST_BUILD_BENCHMARKS=ON`, it is off by default):

```bash
cmake -DCREST_BUILD_BENCHMARKS=ON build && ninja -C build crest-bench-cpp
```

Then, giving one `--crest-opt` for each binary you want in the table (`LABEL=` names it; a boot-mode build is the one with
`-DCREST_EMBED_SCHEME_BOOT=ON`):

```bash
python3 benchmarks/run.py \
  --crest-opt dev=build/tools/crest-opt/crest-opt \
  --crest-opt boot=build-boot/tools/crest-opt/crest-opt \
  --cpp-opt build/benchmarks/cpp/crest-bench-cpp
```

Two ways to measure:

- Default: CPU time (user plus system) of each `crest-opt` process, the best of `--repeat` runs. It is what a user sees, but it depends on the
  other work on the machine, and a few percent of noise is normal. Do not run it beside the test suite.
- `--instructions`: the number of instructions each process executes, counted by valgrind's callgrind. It is exactly the same on every run,
  whatever the load of the machine, so one run is enough and the runs go in parallel (about a minute). It does not see cache misses.
  Use it to compare, and to check a change.

`--sizes` changes the module sizes (numbers of functions), `--check` makes the run exit with 1 when the cost per function is not steady.

To make a module by hand: `python3 benchmarks/generate-module.py 1000 > module.mlir` (`--no-match` for the variant that no pattern fuses), then

```bash
CREST_PATH=$PWD/samples:$PWD/benchmarks build/tools/crest-opt/crest-opt -allow-unregistered-dialect \
  --crest-pass="passes=passes/qadd-only" module.mlir
```

## How to read the tables

```
variant   functions   ops   no pass   with pass   pass cost   us/function   us/op   spread
```

- `no pass`: the tool with no pass: parse and print only.
- `with pass`: the same with the pass.
- `pass cost`: with pass minus no pass. It includes the start-up, which is printed above the table.
- `us/function` (`kinstr/function` with `--instructions`): the cost of one more function, from the difference between this size and the one
  before it. Start-up cancels out, so this is the number to compare. For the first size the comparison is with the empty module, which is
  noisy in CPU time.
- `spread`: how much the runs differ (slowest against fastest). A large spread means the machine was busy. It is 0 for instructions.

The last table compares the cost of one more function at the largest size, and divides it by the C++ one.

## Rules that keep the numbers fair

- Same module for every tool, and the same output (checked, byte for byte, between the tools of one comparison).
- Every run with the pass is checked: the output must contain the expected number of `hip.qadd` (one per function for `match`, none for
  `no-match`). A run that fused nothing would give fast and wrong numbers, so the script stops.
- MLIR threading is off (`-mlir-disable-threading`), so the numbers do not depend on the number of cores.
- Start-up and per-function cost are reported separately and never added.
- Keep the load average, the machine and the LLVM version with any CPU-time numbers you publish. The script prints all three.
