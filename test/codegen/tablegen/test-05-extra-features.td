// Test 05: Extra Features
// Features: extraClassDeclaration, hasNonDefaultDestructor, hasOperationInterfaceFallback, isExtensible

include "mlir/IR/DialectBase.td"

def Test05ExtraDecl_Dialect : Dialect {
  let name = "test05extradecl";
  let cppNamespace = "::mlir::test05extradecl";
  let description = [{ Dialect with extra class declarations. }];
  let extraClassDeclaration = [{
    // Custom helper methods
    static bool isQuantizedType(Type type);
    void registerCustomPasses();
  }];
}

def Test05NonDefaultDtor_Dialect : Dialect {
  let name = "test05nondtor";
  let cppNamespace = "::mlir::test05nondtor";
  let description = [{ Dialect with non-default destructor. }];
  let hasNonDefaultDestructor = 1;
}

def Test05OpInterfaceFallback_Dialect : Dialect {
  let name = "test05fallback";
  let cppNamespace = "::mlir::test05fallback";
  let description = [{ Dialect with operation interface fallback. }];
  let hasOperationInterfaceFallback = 1;
}

def Test05Extensible_Dialect : Dialect {
  let name = "test05extensible";
  let cppNamespace = "::mlir::test05extensible";
  let description = [{ Extensible dialect (can add ops/types at runtime). }];
  let isExtensible = 1;
}
