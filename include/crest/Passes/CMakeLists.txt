##
# CREST public pass declarations — generates Passes.h.inc into the build tree.
# Output: ${CMAKE_CURRENT_BINARY_DIR}/Passes.h.inc
# Consumers include it as "crest/Passes/Passes.h.inc" when
# ${CMAKE_BINARY_DIR}/include is on the include path.
##

set(LLVM_TARGET_DEFINITIONS Passes.td)
mlir_tablegen(Passes.h.inc -gen-pass-decls -name Scheme)
add_public_tablegen_target(CrestSchemePassIncGen)
