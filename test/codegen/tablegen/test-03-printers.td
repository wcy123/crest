// Test 03: Attribute and Type Printers/Parsers
// Features: useDefaultAttributePrinterParser, useDefaultTypePrinterParser

include "mlir/IR/DialectBase.td"

def Test03DefaultAttr_Dialect : Dialect {
  let name = "test03defaultattr";
  let cppNamespace = "::mlir::test03defaultattr";
  let description = [{ Dialect with default attribute printer. }];
  let useDefaultAttributePrinterParser = 1;
}

def Test03DefaultType_Dialect : Dialect {
  let name = "test03defaulttype";
  let cppNamespace = "::mlir::test03defaulttype";
  let description = [{ Dialect with default type printer. }];
  let useDefaultTypePrinterParser = 1;
}

def Test03Both_Dialect : Dialect {
  let name = "test03both";
  let cppNamespace = "::mlir::test03both";
  let description = [{ Dialect with both default printers. }];
  let useDefaultAttributePrinterParser = 1;
  let useDefaultTypePrinterParser = 1;
}
