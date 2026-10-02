##
# CREST Bindings — Chez Scheme / MLIR integration
##

add_subdirectory(Dialects)

set(CHEZ_MACHINE_LOCAL "${CHEZ_MACHINE}")

add_library(CrestBindings STATIC
  ${CMAKE_CURRENT_SOURCE_DIR}/../Interpreter/ChezSchemeInterpreter.cpp
  MainModule.cpp
  Core.cpp
  Core/Attribute.cpp
  Core/Operation.cpp
  Core/Value.cpp
  Core/Builder.cpp
  Logging.cpp
  Conversion.cpp
  Dialects/Tensor.cpp
  Dialects/Shape.cpp
)

target_include_directories(CrestBindings
  PUBLIC
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}
  PRIVATE
    ${CMAKE_SOURCE_DIR}/include
    ${ChezBootHeaders_BINARY_DIR}
    ${ChezScheme_SOURCE_DIR}/boot/pb
    ${LLVM_INCLUDE_DIRS}
    ${MLIR_INCLUDE_DIRS}
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
  PRIVATE
    ChezScheme
)
