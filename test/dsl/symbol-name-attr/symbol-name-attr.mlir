// mlir::OpAsmParser::parseSymbolName(StringAttr&, StringRef attrName, NamedAttrList&) stores the
// name under the attribute name it is given. The binding hard-coded "callee", so an op could not
// choose its own attribute name. Here the op stores it as "target".
//
// RUN: env CREST_PATH=%S CREST_SCHEME_BINARY_DIR=%t/scheme \
// RUN:   %scheme-mlir %S/../../toy/toy-ir.sls symdialect %s verify | FileCheck %s

// CHECK: "toy.ref"() {target = "foo"} : () -> ()

toy.ref @foo
