// The C symbols that the bindings register follow Rule 4: one registration for each key (the second would
// silently replace the first), and an overload told apart by <types>, not by a suffix like /len or .f32.
//
// RUN: python3 %S/check-symbol-names.py %S/../..

module {}
