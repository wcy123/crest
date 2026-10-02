##
# CREST Passes — tablegen-generated SchemePass infrastructure
##

set(LLVM_TARGET_DEFINITIONS Passes.td)
mlir_tablegen(Passes.h.inc -gen-pass-decls -name Scheme)
add_public_tablegen_target(CrestSchemePassIncGen)

add_library(CrestPasses STATIC SchemePass.cpp)
add_dependencies(CrestPasses CrestSchemePassIncGen)

target_include_directories(CrestPasses
  PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}   # for generated Passes.h.inc
    ${CMAKE_CURRENT_SOURCE_DIR}   # for Passes.h and ChezSchemeInterpreter.h
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
