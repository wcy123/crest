##
# CREST Bindings — Chez Scheme / MLIR integration
##

add_library(CrestBindings STATIC
  MainModule.cpp
  Core/Builder.cpp
  Dialect/Shape/IR/Shape.cpp
  Interfaces/DestinationStyleOp.cpp
  IR/Block.cpp
  IR/BuiltinAttributes.cpp
  IR/BuiltinTypes.cpp
  IR/OpBuilder.cpp
  IR/Operation.cpp
  IR/OpResult.cpp
  IR/RewriterBase.cpp
  IR/Type.cpp
  IR/Value.cpp
  Support/ArrayRef.cpp
  Support/Logging.cpp
  Support/LockedSchemeObject.cpp
  Transforms/DialectConversion.cpp
  Transforms/GreedyPatternRewriteDriver.cpp
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
