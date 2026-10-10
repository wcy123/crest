##
# CREST Bindings — Chez Scheme / MLIR integration
#
# CrestBindings owns the Chez Scheme build artifacts (scheme.h, libkernel.a,
# liblz4.a, libz.a). CrestInterpreter and other targets get them transitively.
##

add_library(CrestBindings STATIC
  MainModule.cpp
  Dialect/Shape/IR/Shape.cpp
  Dialect/Tensor/Tensor.cpp
  Interfaces/DestinationStyleOp.cpp
  IR/Location.cpp
  IR/Block.cpp
  IR/Region.cpp
  IR/BuiltinAttributes.cpp
  IR/MLIRContext.cpp
  IR/BuiltinTypes.cpp
  IR/OperationState.cpp
  IR/OpBuilder.cpp
  IR/Operation.cpp
  IR/OpResult.cpp
  IR/PatternMatch.cpp
  IR/Type.cpp
  IR/Value.cpp
  Support/ArrayRef.cpp
  Support/CrestObject.cpp
  Support/SchemeWrapper.cpp
  Support/Logging.cpp
  Support/LockedSchemeObject.cpp
  Transforms/DialectConversion.cpp
  Transforms/GreedyPatternRewriteDriver.cpp
)

add_dependencies(CrestBindings ChezScheme ChezBootHeaders)

target_include_directories(CrestBindings
  PUBLIC
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}  # scheme.h
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(CrestBindings
  PUBLIC
    MLIRIR
    MLIRFuncDialect
    MLIRTensorDialect
    MLIRShapeDialect
    MLIRTransforms
    MLIRDialectUtils
    MLIRTransformUtils
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/libkernel.a
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/lz4/lib/liblz4.a
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/zlib/libz.a
    ${CMAKE_DL_LIBS}
    m
    pthread
    ncurses
)
