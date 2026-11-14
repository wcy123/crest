// A failed match is logged with the op that it was given, so printing one op must not depend on the size of the
// module that holds it. A module 25 times bigger must not make the print 25 times slower
// (check-print-scaling.py).
//
// RUN: python3 %S/check-print-scaling.py %scheme-mlir %samples %S/print-scaling.sls

module {}
