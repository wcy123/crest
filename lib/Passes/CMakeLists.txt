##
# CREST Passes — SchemePass implementation.
# Tablegen target CrestSchemePassIncGen is defined in include/crest/Passes/.
##

add_library(CrestPasses STATIC SchemePass.cpp)
add_dependencies(CrestPasses CrestSchemePassIncGen)

target_include_directories(CrestPasses
  PUBLIC
    ${CMAKE_SOURCE_DIR}/include          # for crest/Passes/Passes.h
    ${CMAKE_BINARY_DIR}/include          # for crest/Passes/Passes.h.inc (generated)
  PRIVATE
    ${LLVM_INCLUDE_DIRS}
    ${MLIR_INCLUDE_DIRS}
)

target_link_libraries(CrestPasses
  PUBLIC
    CrestBindings
    MLIRPass
    MLIRFuncDialect
    MLIRShapeDialect
    MLIRIR
    MLIRSupport
)
