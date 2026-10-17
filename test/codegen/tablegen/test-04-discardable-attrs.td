// Test 04: Discardable Attributes
// Features: discardableAttrs (DAG type) - generates type-safe helpers

include "mlir/IR/DialectBase.td"

def Test04NoDiscardable_Dialect : Dialect {
  let name = "test04nodiscard";
  let cppNamespace = "::mlir::test04nodiscard";
  let description = [{ Dialect with no discardable attributes (default). }];
  // discardableAttrs defaults to (ins) - empty
}

def Test04SingleDiscardable_Dialect : Dialect {
  let name = "test04single";
  let cppNamespace = "::mlir::test04single";
  let description = [{ Dialect with single discardable attribute. }];
  let discardableAttrs = (ins
    "WorkgroupAttr":$workgroup
  );
}

def Test04MultipleDiscardable_Dialect : Dialect {
  let name = "test04multiple";
  let cppNamespace = "::mlir::test04multiple";
  let description = [{ Dialect with multiple discardable attributes. }];
  let discardableAttrs = (ins
    "WorkgroupAttr":$workgroup,
    "TargetAttr":$target,
    "OptimizationLevelAttr":$opt_level
  );
}
