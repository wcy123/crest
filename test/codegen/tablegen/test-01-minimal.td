// Test 01: Minimal dialect - only required fields
// Features: name, cppNamespace, description

include "mlir/IR/DialectBase.td"

def Test01_Dialect : Dialect {
  let name = "test01";
  let cppNamespace = "::mlir::test01";
  let description = [{
    Minimal test dialect with only required fields.
    No dependencies, no optional features.
  }];
}
