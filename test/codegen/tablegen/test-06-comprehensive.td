// Test 06: Comprehensive - ALL 17 features enabled
// This dialect exercises EVERY possible TableGen dialect field

include "mlir/IR/DialectBase.td"

def Test06Comprehensive_Dialect : Dialect {
  // Basic properties (4 fields)
  let name = "test06";
  let summary = "Comprehensive test dialect with all 17 fields";
  let description = [{
    This dialect enables ALL 17 TableGen dialect features to ensure complete coverage:
    - Basic: name, summary, description, cppNamespace
    - Dependencies: dependentDialects
    - Discardable attrs: discardableAttrs (DAG type)
    - Printers: useDefaultAttributePrinterParser, useDefaultTypePrinterParser
    - Capabilities: 6 has* flags
    - Lifecycle: hasNonDefaultDestructor
    - Extensibility: isExtensible
    - Extra code: extraClassDeclaration
  }];
  let cppNamespace = "::mlir::test06";

  // Dependencies (1 field)
  let dependentDialects = [
    "arith::ArithDialect",
    "tensor::TensorDialect"
  ];

  // Discardable attributes (1 field - DAG type)
  let discardableAttrs = (ins
    // Type-safe helpers for discardable attributes
    "CustomWorkgroupAttr":$workgroup_config,
    "TargetDeviceAttr":$target_device
  );

  // Printers/Parsers (2 fields)
  let useDefaultAttributePrinterParser = 1;
  let useDefaultTypePrinterParser = 1;

  // Capabilities (6 fields)
  let hasConstantMaterializer = 1;
  let hasCanonicalizer = 1;
  let hasOperationAttrVerify = 1;
  let hasRegionArgAttrVerify = 1;
  let hasRegionResultAttrVerify = 1;
  let hasOperationInterfaceFallback = 1;

  // Lifecycle (1 field)
  let hasNonDefaultDestructor = 1;

  // Extensibility (1 field)
  let isExtensible = 1;

  // Extra code (1 field)
  let extraClassDeclaration = [{
    // Project-specific helpers
    static bool isQuantizedType(Type type);
    void registerCustomPasses();
    Type parseCustomType(DialectAsmParser &parser);
  }];
}

// Field count verification: 4 + 1 + 1 + 2 + 6 + 1 + 1 + 1 = 17 fields total
