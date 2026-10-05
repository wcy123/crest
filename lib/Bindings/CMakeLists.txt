##
# CREST Bindings — Chez Scheme / MLIR integration
##

add_library(CrestBindings STATIC
  MainModule.cpp
  # IR layer — mirrors mlir/IR/
  IR/Block.cpp
  IR/BuiltinAttributes.cpp
  IR/BuiltinTypes.cpp
  IR/OpBuilder.cpp
  IR/OpResult.cpp
  IR/Operation.cpp
  IR/RewriterBase.cpp
  IR/Type.cpp
  IR/Value.cpp
  # Dialect layer
  Dialect/Shape/IR/Shape.cpp
  # Interfaces layer
  Interfaces/DestinationStyleOp.cpp
  # Transforms layer
  Transforms/DialectConversion.cpp
  Transforms/GreedyPatternRewriteDriver.cpp
  # Support
  Support/ArrayRef.cpp
  Support/Logging.cpp
  Support/LockedSchemeObject.cpp
  # Core registration hub + backward-compat shims
  # (these register old C names still used by scheme/mlir/core/*.sls)
  Core/Core.cpp
  Core/Attribute.cpp
  Core/Builder.cpp
  Core/Conversion.cpp
  Core/Operation.cpp
  Core/Types.cpp
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
