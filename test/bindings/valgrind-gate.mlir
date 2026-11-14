// The check of the valgrind logs (tools/check-valgrind-logs.py) fails on a leak and on a use after free, and passes a
// clean run. It is run here on logs that are written for the test.
//
// RUN: python3 %S/check-valgrind-gate.py %S/../..

module {}
