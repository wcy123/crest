##
# CREST Bindings — Chez Scheme / MLIR integration
##

add_subdirectory(Dialects)

set(CHEZ_MACHINE_LOCAL "${CHEZ_MACHINE}")

add_library(CrestBindings STATIC
  MainModule.cpp
  LockedSchemeObject.cpp
  Core.cpp
  Core/Attribute.cpp
  Core/Operation.cpp
  Core/Value.cpp
  Core/Builder.cpp
  Core/Types.cpp
  Logging.cpp
  Conversion.cpp
  Dialects/Shape.cpp
  Support/ArrayRef.cpp
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
