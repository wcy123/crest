##
# CREST Bindings — Chez Scheme / MLIR integration
##

add_library(CrestBindings STATIC
  MainModule.cpp
  Transforms/DialectConversion.cpp
  Core/Core.cpp
  IR/Block.cpp
  IR/BuiltinAttributes.cpp
  IR/BuiltinTypes.cpp
  IR/Operation.cpp
  IR/Type.cpp
  IR/Value.cpp
  IR/OpResult.cpp
  Interfaces/DestinationStyleOp.cpp
  Core/Builder.cpp
  IR/OpBuilder.cpp
  IR/RewriterBase.cpp
  Transforms/GreedyPatternRewriteDriver.cpp
  Dialect/Shape/IR/Shape.cpp
  Support/ArrayRef.cpp
  Support/Logging.cpp
  Support/LockedSchemeObject.cpp
)

target_include_directories(CrestBindings
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(CrestBindings
  PUBLIC
    CrestInterpreter
    MLIRIR
    MLIRFuncDialect
    MLIRTensorDialect
    MLIRShapeDialect
    MLIRTransforms
    MLIRDialectUtils
    MLIRTransformUtils
)
