// Test 02: Dependent dialects
// Features: dependentDialects (single and multiple)

include "mlir/IR/DialectBase.td"

def Test02Single_Dialect : Dialect {
  let name = "test02single";
  let cppNamespace = "::mlir::test02single";
  let description = [{
    Dialect with single dependency.
  }];
  let dependentDialects = ["arith::ArithDialect"];
}

def Test02Multiple_Dialect : Dialect {
  let name = "test02multiple";
  let cppNamespace = "::mlir::test02multiple";
  let description = [{
    Dialect with multiple dependencies.
  }];
  let dependentDialects = [
    "affine::AffineDialect",
    "arith::ArithDialect",
    "complex::ComplexDialect"
  ];
}
