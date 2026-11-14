// The check of the valgrind logs (tools/check-valgrind-logs.py) fails on a leak and on a use after free, passes a
// clean run, and excuses only the leaks of runs that end the process on purpose
// (test/valgrind-ends-the-process.txt). It is run here on logs that are written for the test.
//
// RUN: python3 %S/check-valgrind-gate.py %S/../..

module {}
