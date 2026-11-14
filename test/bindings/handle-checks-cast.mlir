// A binding that is given a pointer of the wrong kind answers an error (Rule 20): `mlir::cast` of
// a pointer that is not a T is undefined behaviour in a release build, so the bindings check it. Each
// case is a run of its own (a fault ends the process); see handle-checks-cast.sls.
//
// RUN: %scheme-mlir %S/handle-checks-cast.sls engine-null 2>&1 | %FileCheck %s --check-prefix=ENGINE-NULL
// RUN: %scheme-mlir %S/handle-checks-cast.sls engine-not-module 2>&1 | %FileCheck %s --check-prefix=ENGINE-NOT-MODULE
// RUN: %scheme-mlir %S/handle-checks-cast.sls arith-constant-null 2>&1 | %FileCheck %s --check-prefix=ARITH-CONSTANT-NULL
// RUN: %scheme-mlir %S/handle-checks-cast.sls arith-constant-untyped 2>&1 | %FileCheck %s --check-prefix=ARITH-CONSTANT-UNTYPED
// RUN: %scheme-mlir %S/handle-checks-cast.sls string-attr-null 2>&1 | %FileCheck %s --check-prefix=STRING-ATTR
// RUN: %scheme-mlir %S/handle-checks-cast.sls function-type-wrong 2>&1 | %FileCheck %s --check-prefix=FUNCTION-TYPE
// RUN: %scheme-mlir %S/handle-checks-cast.sls func-body-wrong 2>&1 | %FileCheck %s --check-prefix=FUNC-BODY
// RUN: %scheme-mlir %S/handle-checks-cast.sls module-body-wrong 2>&1 | %FileCheck %s --check-prefix=MODULE-BODY

// ENGINE-NULL: mlir::ExecutionEngine::create: module pointer is null
// ENGINE-NOT-MODULE: mlir::ExecutionEngine::create: {{.*}} not a module
// ARITH-CONSTANT-NULL: mlir::arith::ConstantOp::create<f64>: attribute pointer is null
// ARITH-CONSTANT-UNTYPED: mlir::arith::ConstantOp::create<f64>: {{.*}} not a typed attribute
// STRING-ATTR: mlir::StringAttr::getValue: the pointer is null or not a StringAttr
// FUNCTION-TYPE: mlir::FunctionType::getNumInputs: the pointer is null or not a FunctionType
// FUNC-BODY: mlir::func::FuncOp::getBody: the pointer is null or not a FuncOp
// MODULE-BODY: mlir::ModuleOp::getBody: the operation is not a module

module {}
