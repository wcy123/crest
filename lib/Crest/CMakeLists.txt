##
# CrestCore — OBJECT library for the Crest dialect/op bridge.
#
# Built as an OBJECT library (not STATIC) so the compiled objects can be
# linked into CrestBindings without a circular library dependency:
#   CrestCore needs LockedSchemeObject/SchemeWrapper (in CrestBindings/Support/)
#   CrestBindings needs CrestCore (for registerIR*Bindings)
#
# OBJECT libraries resolve the cycle: CrestBindings includes CrestCore's
# compiled object files directly via $<TARGET_OBJECTS:CrestCore>.
#
# Future clean-up: move lib/Bindings/Support/ to lib/Crest/Support/ so
# CrestCore can be a proper STATIC library with no circular dependency.
##

add_library(CrestCore OBJECT
  Dialect.cpp
  Dialect.h
  Op.cpp
  Op.h
)

add_dependencies(CrestCore ChezScheme ChezBootHeaders)

target_include_directories(CrestCore
  PRIVATE
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}  # scheme.h
    ${CMAKE_CURRENT_SOURCE_DIR}/..             # lib/ — Bindings/Support/...
)

target_link_libraries(CrestCore
  PRIVATE
    MLIRIR
)
