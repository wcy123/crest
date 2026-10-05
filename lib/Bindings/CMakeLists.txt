##
# CREST Bindings — Chez Scheme / MLIR integration
##

add_library(CrestBindings STATIC
  MainModule.cpp
  Core/Conversion.cpp
  Transforms/DialectConversion.cpp
  Core/Core.cpp
  Core/Attribute.cpp
  Core/Operation.cpp
  IR/Block.cpp
  IR/BuiltinAttributes.cpp
  IR/BuiltinTypes.cpp
  IR/Operation.cpp
  IR/Type.cpp
  IR/Value.cpp
  IR/OpResult.cpp
  Interfaces/DestinationStyleOp.cpp
  Core/Builder.cpp
  Core/Types.cpp
  IR/Block.cpp
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
