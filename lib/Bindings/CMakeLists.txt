##
# CREST Bindings — Chez Scheme / MLIR integration
##

add_library(CrestBindings STATIC
  MainModule.cpp
  Conversion.cpp
  Core/Core.cpp
  Core/Attribute.cpp
  Core/Operation.cpp
  Core/Value.cpp
  Core/Builder.cpp
  Core/Types.cpp
  Dialects/Shape.cpp
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
