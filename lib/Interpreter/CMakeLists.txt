##
# CrestInterpreter — Chez Scheme runtime wrapper
#
# ChezScheme_SOURCE_DIR, ChezScheme_BINARY_DIR, ChezBootHeaders_BINARY_DIR,
# and CHEZ_MACHINE are set by cmake/deps.cmake (included from the top-level
# CMakeLists.txt) before this file is processed.
##

add_library(CrestInterpreter STATIC ChezSchemeInterpreter.cpp)
add_dependencies(CrestInterpreter ChezScheme ChezBootHeaders)

target_include_directories(CrestInterpreter
  PUBLIC
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}  # scheme.h
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}               # ChezSchemeInterpreter.h
    ${ChezBootHeaders_BINARY_DIR}             # ChezBootPetite.h, ChezBootScheme.h, CrestBoot.h
    ${ChezScheme_SOURCE_DIR}/boot/pb          # pb/scheme.h fallback
)

if(CREST_EMBED_SCHEME_BOOT)
  target_compile_definitions(CrestInterpreter PRIVATE CREST_BOOT_EMBEDDED)
endif()

# SCHEME_BINARY_DIR is always defined so CREST_PATH works in both modes.
# In dev mode it caches compiled .so files; in boot mode it is unused
# (the boot already has everything) but must compile cleanly.
# Note: PROJECT_SOURCE_DIR / PROJECT_BINARY_DIR refer to the crest project root,
# not the lib/Interpreter/ subdirectory, so they correctly point to scheme/.
target_compile_definitions(CrestInterpreter PRIVATE
  SCHEME_LIBRARIES_DIR="${PROJECT_SOURCE_DIR}/scheme"
  SCHEME_BINARY_DIR="${PROJECT_BINARY_DIR}/scheme"
  RIME_DIR="${CREST_RIME_DIR}"
)

target_link_libraries(CrestInterpreter
  PUBLIC
    MLIRIR
  PRIVATE
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/libkernel.a
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/lz4/lib/liblz4.a
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/zlib/libz.a
    ${CMAKE_DL_LIBS}
    m
    pthread
    ncurses
)
