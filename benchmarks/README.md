# Benchmarks

What the hip-fusion pass costs, measured on generated modules. It answers three questions:

1. How long does `crest-opt` take to start with a CREST pass (Chez and the libraries), in development mode and in boot mode?
2. What does one more function cost, when its fusion matches and when it does not?
3. Does that cost stay the same when the module grows? A cost that grows faster than the module (quadratic) is what `--check` looks for.

This directory is not part of `check-crest`. Nothing here is built; it is two Python scripts and a built `crest-opt`.

## Run it

```bash
python3 benchmarks/run.py \
  --crest-opt dev=build/tools/crest-opt/crest-opt \
  --crest-opt boot=build-boot/tools/crest-opt/crest-opt
```

Give one `--crest-opt` for each binary you want in the table; `LABEL=` names it. `--sizes` and `--repeat` change the module
sizes (numbers of functions) and the number of runs. `--check` makes the run exit with 1 when the cost per function is not
steady. With the default sizes the run takes a few minutes.

To make a module by hand: `python3 benchmarks/generate-module.py 1000 > module.mlir` (`--no-match` for the variant that no pattern
fuses), then

```bash
CREST_PATH=$PWD/samples build/tools/crest-opt/crest-opt -allow-unregistered-dialect \
  --crest-pass="passes=passes/hip-fusion" module.mlir
```

## How to read the table

```
variant   functions   ops   no pass s   with pass s   pass cost   us/function   us/op   spread
```

- `no pass s`: `crest-opt` with no pass: parse and print only.
- `with pass s`: the same with `--crest-pass=passes=passes/hip-fusion`.
- `pass cost`: with pass minus no pass. It includes the start-up, which is printed above the table.
- `us/function`: the cost of one more function, from the difference between this size and the one before it. Start-up cancels out, so
  this is the number to compare. For the first size the comparison is with the empty module.
- `spread`: how much the runs with the pass differ (slowest against fastest). A large spread means the machine was busy.

## Rules that keep the numbers fair

- Same module for every binary.
- CPU time (user plus system) of the `crest-opt` process, the best of several runs. Wall time depends on the other work on the machine.
- MLIR threading is off (`-mlir-disable-threading`), so the CPU time does not depend on the number of cores.
- Start-up and per-function cost are reported separately and never added.
- Every run with the pass is checked: the output must contain the expected number of `hip.qadd` (one per function for `match`, none for
  `no-match`). A run that fused nothing would give fast and wrong numbers, so the script stops.
- Run it on a quiet machine, not beside the test suite, and keep the load average, the machine and the LLVM version with any numbers you
  publish. The script prints all three.
