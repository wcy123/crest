// A pass name that is not a library name is an error of the pass, not a Scheme exception that ends the
// process: the name is read as Scheme text ("a/." is "(a .)"), and the read has to be inside the guard.
//
// RUN: not env CREST_PATH=%S %crest-opt %s --crest-pass="passes=a/." 2>&1 | %FileCheck %s --check-prefix=DOT
// RUN: not env CREST_PATH=%S %crest-opt %s --crest-pass="passes=." 2>&1 | %FileCheck %s --check-prefix=ONLY-DOT

// DOT: error: Failed to import Scheme library: a/.:
// ONLY-DOT: error: Failed to import Scheme library: .:

module {
}
