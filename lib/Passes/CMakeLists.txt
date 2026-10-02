##
# CREST Passes — SchemePass implementation.
# Tablegen target CrestSchemePassIncGen is defined in include/crest/Passes/.
##

add_library(CrestPasses STATIC SchemePass.cpp)
add_dependencies(CrestPasses CrestSchemePassIncGen)

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
