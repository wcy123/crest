##
# CrestCore — OBJECT library for the Crest dialect/op bridge.
#
# Built as an OBJECT library (not STATIC) so the compiled objects can be
# linked into CrestBindings without a circular library dependency:
#   CrestCore needs SchemeWrapper (in CrestBindings/Support/)
#   CrestBindings needs CrestCore (for registerIR*Bindings)
#
# OBJECT libraries resolve the cycle: CrestBindings includes CrestCore's
# compiled object files directly via $<TARGET_OBJECTS:CrestCore>.
#
# Future clean-up: move lib/Bindings/Support/ to lib/Crest/Support/ so
# CrestCore can be a proper STATIC library with no circular dependency.
##

# DynamicOpDefinition::addTrait() requires LLVM 23+.
# Compile the real Trait.cpp on LLVM 23+; fall back to TraitStub.cpp
# which registers an error stub so Scheme gets a clear diagnostic.
if(LLVM_VERSION_MAJOR GREATER_EQUAL 23)
  message(STATUS "CREST: LLVM ${LLVM_VERSION_MAJOR} >= 23 — DynamicOpTrait enabled")
  set(CREST_TRAIT_SOURCE Trait.cpp Trait.h)
else()
  message(STATUS "CREST: LLVM ${LLVM_VERSION_MAJOR} < 23 — DynamicOpTrait stubbed out")
  set(CREST_TRAIT_SOURCE TraitStub.cpp Trait.h)
endif()

add_library(CrestCore OBJECT
  Dialect.cpp
  Dialect.h
  InferType.cpp
  InferType.h
  InlinerInterface.cpp
  InlinerInterface.h
  Op.cpp
  Op.h
  SchemePass.cpp
  SchemePass.h
  Type.cpp
  Type.h
  ${CREST_TRAIT_SOURCE}
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
