// An op whose result types are inferred from its regions (scf.if) cannot leave out `-> type` in an
// op-form: begin-mlir-code fills the regions after the op exists, so inference sees them empty. C++ is
// the same (the scf::IfOp builders take the result types). With the type it builds; without it the
// error says why and what to write, and not only "cannot infer".
//
// RUN: %scheme-mlir %S/scf-if.sls explicit | %FileCheck %s --check-prefix=EXPLICIT
// RUN: not %scheme-mlir %S/scf-if.sls inferred 2>&1 | %FileCheck %s --check-prefix=INFERRED

// EXPLICIT: %{{.*}} = scf.if %{{.*}} -> (i64) {
// INFERRED: cannot infer the result types of scf.if: its regions are still empty when the types are inferred (they are filled after the op is created); write -> type
