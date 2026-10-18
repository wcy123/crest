// Test 04: Dialect Capabilities
// Features: hasConstantMaterializer, hasCanonicalizer, verifiers

include "mlir/IR/DialectBase.td"

def Test04ConstMat_Dialect : Dialect {
  let name = "test04constmat";
  let cppNamespace = "::mlir::test04constmat";
  let description = [{ Dialect with constant materializer. }];
  let hasConstantMaterializer = 1;
}

def Test04Canon_Dialect : Dialect {
  let name = "test04canon";
  let cppNamespace = "::mlir::test04canon";
  let description = [{ Dialect with canonicalizer. }];
  let hasCanonicalizer = 1;
}

def Test04OpAttrVerify_Dialect : Dialect {
  let name = "test04opattrverify";
  let cppNamespace = "::mlir::test04opattrverify";
  let description = [{ Dialect with operation attribute verification. }];
  let hasOperationAttrVerify = 1;
}

def Test04RegionArgAttrVerify_Dialect : Dialect {
  let name = "test04regionargverify";
  let cppNamespace = "::mlir::test04regionargverify";
  let description = [{ Dialect with region argument attribute verification. }];
  let hasRegionArgAttrVerify = 1;
}

def Test04RegionResultAttrVerify_Dialect : Dialect {
  let name = "test04regionresultverify";
  let cppNamespace = "::mlir::test04regionresultverify";
  let description = [{ Dialect with region result attribute verification. }];
  let hasRegionResultAttrVerify = 1;
}
