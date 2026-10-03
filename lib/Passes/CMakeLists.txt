##
# CREST Passes — CrestPass implementation.
# No tablegen — uses mlir::PassPipelineRegistration directly.
##

add_library(CrestPasses STATIC CrestPass.cpp)

# include/ and build/include/ are set globally; no per-target repetition needed

target_link_libraries(CrestPasses
  PUBLIC
    CrestBindings
    MLIRPass
    MLIRFuncDialect
    MLIRShapeDialect
    MLIRIR
    MLIRSupport
)
