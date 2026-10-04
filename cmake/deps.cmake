##
# cmake/deps.cmake — CREST third-party dependencies
#
# Downloads ChezScheme and rime at configure time via FetchContent,
# then builds ChezScheme from source via ExternalProject_Add.
#
# Exported cache variables (available to all subdirectories):
#   ChezScheme_SOURCE_DIR      — fetched ChezScheme source tree
#   ChezScheme_BINARY_DIR      — ChezScheme build output
#   ChezBootHeaders_BINARY_DIR — generated ChezBootPetite.h / ChezBootScheme.h
#   CHEZ_MACHINE               — machine type string (e.g. ta6le)
#   CREST_RIME_DIR             — rime source tree
##

include(FetchContent)
include(ExternalProject)
find_package(Python3 COMPONENTS Interpreter REQUIRED)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "Chez Scheme integration requires 64-bit architecture")
endif()

# ─── Chez Scheme machine type ─────────────────────────────────────────────────
if(WIN32)
  set(CHEZ_MACHINE "ta6nt")
else()
  set(CHEZ_MACHINE "ta6le")
endif()
set(CHEZ_MACHINE "${CHEZ_MACHINE}" CACHE INTERNAL "")
message(STATUS "CREST: Chez Scheme machine type: ${CHEZ_MACHINE}")

# ─── Honour CMAKE_C_COMPILER_LAUNCHER (e.g. sccache) ─────────────────────────
if(CMAKE_C_COMPILER_LAUNCHER)
  set(CHEZ_CC "${CMAKE_C_COMPILER_LAUNCHER} ${CMAKE_C_COMPILER}")
else()
  set(CHEZ_CC "${CMAKE_C_COMPILER}")
endif()

# ─── ChezScheme: fetch source ─────────────────────────────────────────────────
# GIT_SUBMODULES_RECURSE populates zuo, zlib, lz4, nanopass, stex automatically.
FetchContent_Declare(ChezScheme
  GIT_REPOSITORY         https://github.com/cisco/ChezScheme.git
  GIT_TAG                e95a7efbafa2cf3bd5343ea542e6bc909a7ab2c4
  GIT_SUBMODULES_RECURSE TRUE
  GIT_PROGRESS           TRUE
)
FetchContent_GetProperties(ChezScheme)
if(NOT chezscheme_POPULATED)
  FetchContent_Populate(ChezScheme)
endif()
set(ChezScheme_SOURCE_DIR "${chezscheme_SOURCE_DIR}" CACHE INTERNAL "")
set(ChezScheme_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/ChezScheme-build" CACHE INTERNAL "")

# ─── ChezScheme: build ────────────────────────────────────────────────────────
ExternalProject_Add(ChezScheme
  SOURCE_DIR ${ChezScheme_SOURCE_DIR}
  BINARY_DIR ${ChezScheme_BINARY_DIR}
  CONFIGURE_COMMAND
    ${CMAKE_COMMAND} -E chdir <BINARY_DIR>
      ${ChezScheme_SOURCE_DIR}/configure
      --threads
      --disable-x11
      --machine=${CHEZ_MACHINE}
      CC=${CHEZ_CC}
  BUILD_COMMAND
    ${CMAKE_COMMAND} -E chdir <BINARY_DIR> make -j8
  INSTALL_COMMAND ""
  BUILD_BYPRODUCTS
    <BINARY_DIR>/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/petite.boot
    <BINARY_DIR>/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/scheme.boot
    <BINARY_DIR>/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/libkernel.a
    <BINARY_DIR>/${CHEZ_MACHINE}/lz4/lib/liblz4.a
    <BINARY_DIR>/${CHEZ_MACHINE}/zlib/libz.a
)

# ─── ChezScheme: embed .boot files as C byte-array headers ───────────────────
set(ChezBootHeaders_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/ChezBootHeaders" CACHE INTERNAL "")
file(MAKE_DIRECTORY ${ChezBootHeaders_BINARY_DIR})

add_custom_command(
  OUTPUT  ${ChezBootHeaders_BINARY_DIR}/ChezBootPetite.h
  COMMAND ${Python3_EXECUTABLE}
          ${CMAKE_CURRENT_SOURCE_DIR}/cmake/xxd.py
          --var    petite_boot_data
          --output ${ChezBootHeaders_BINARY_DIR}/ChezBootPetite.h
          ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/petite.boot
  DEPENDS ChezScheme
  COMMENT "Embedding petite.boot"
  VERBATIM
)

add_custom_command(
  OUTPUT  ${ChezBootHeaders_BINARY_DIR}/ChezBootScheme.h
  COMMAND ${Python3_EXECUTABLE}
          ${CMAKE_CURRENT_SOURCE_DIR}/cmake/xxd.py
          --var    scheme_boot_data
          --output ${ChezBootHeaders_BINARY_DIR}/ChezBootScheme.h
          ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/scheme.boot
  DEPENDS ChezScheme
  COMMENT "Embedding scheme.boot"
  VERBATIM
)

add_custom_target(ChezBootHeaders DEPENDS
  ${ChezBootHeaders_BINARY_DIR}/ChezBootPetite.h
  ${ChezBootHeaders_BINARY_DIR}/ChezBootScheme.h
)

# ─── rime: fetch source (pure Scheme, no build step) ─────────────────────────
FetchContent_Declare(rime
  GIT_REPOSITORY https://github.com/wcy123/rime.git
  GIT_TAG        7774c48817c0236dd5557a26a923788418833ece
  GIT_PROGRESS   TRUE
)
FetchContent_GetProperties(rime)
if(NOT rime_POPULATED)
  FetchContent_Populate(rime)
endif()
set(CREST_RIME_DIR "${rime_SOURCE_DIR}" CACHE INTERNAL "")

# ─── CREST Scheme boot file (deployment only) ────────────────────────────────
# When CREST_EMBED_SCHEME_BOOT=ON, compile all CREST .sls libraries into a
# single crest.boot, embed it as a C byte-array header, and define
# CREST_BOOT_EMBEDDED so the interpreter loads it at startup.
# When OFF (default), the interpreter searches for .sls files at runtime via
# addLibraryPath — convenient for development.
# NOTE: must come after rime is fetched so CREST_RIME_DIR is set.
# CREST_EMBED_SCHEME_BOOT is declared in cmake/crest-options.cmake

if(CREST_EMBED_SCHEME_BOOT)
  set(CHEZ_SCHEME_BIN
      ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/bin/${CHEZ_MACHINE}/scheme)
  set(CREST_BOOT_FILE   "${CMAKE_CURRENT_BINARY_DIR}/crest.boot")
  set(CREST_BOOT_HEADER "${ChezBootHeaders_BINARY_DIR}/CrestBoot.h")
  set(CREST_SCHEME_OBJ_DIR "${CMAKE_CURRENT_BINARY_DIR}/scheme-objs")

  file(GLOB_RECURSE CREST_SLS_FILES "${CMAKE_CURRENT_SOURCE_DIR}/scheme/*.sls")

  # ── Extensible source dirs and root libraries ─────────────────────────────────
  # Downstream projects can extend these lists BEFORE add_subdirectory(crest):
  #   list(PREPEND CREST_BOOT_SOURCE_DIRS "${MY_SCHEME_DIR}")
  #   list(PREPEND CREST_BOOT_ROOTS       "${MY_SCHEME_DIR}/my-root.sls")
  #
  # CREST always appends its own entries so they're always present.
  list(APPEND CREST_BOOT_SOURCE_DIRS
       "${CMAKE_CURRENT_SOURCE_DIR}/scheme"
       "${CREST_RIME_DIR}")
  list(REMOVE_DUPLICATES CREST_BOOT_SOURCE_DIRS)

  list(APPEND CREST_BOOT_ROOTS
       "${CMAKE_CURRENT_SOURCE_DIR}/scheme/passes/hip-fusion.sls")
  list(REMOVE_DUPLICATES CREST_BOOT_ROOTS)

  list(LENGTH CREST_BOOT_SOURCE_DIRS _crest_n_src_dirs)

  # ── Compile all libraries via compile-imported-libraries ─────────────────────
  # Chez handles topological ordering automatically.
  # library-directories (source . object) pairs redirect output to obj-dir.
  add_custom_command(
    OUTPUT  ${CREST_BOOT_FILE}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CREST_SCHEME_OBJ_DIR}
    COMMAND ${CHEZ_SCHEME_BIN}
            --script ${CMAKE_CURRENT_SOURCE_DIR}/cmake/compile_scheme_libs.ss
            ${CREST_SCHEME_OBJ_DIR}       # obj-dir
            ${CREST_BOOT_FILE}            # output-boot
            ${_crest_n_src_dirs}          # number of source-dirs that follow
            ${CREST_BOOT_SOURCE_DIRS}     # source-dir... (expanded list)
            ${CREST_BOOT_ROOTS}           # root-sls...  (expanded list)
    DEPENDS ChezScheme ${CREST_SLS_FILES} ${CREST_BOOT_ROOTS}
            ${CMAKE_CURRENT_SOURCE_DIR}/cmake/compile_scheme_libs.ss
    COMMENT "Compiling CREST Scheme libraries into crest.boot"
    VERBATIM
  )

  add_custom_command(
    OUTPUT  ${CREST_BOOT_HEADER}
    COMMAND ${Python3_EXECUTABLE}
            ${CMAKE_CURRENT_SOURCE_DIR}/cmake/xxd.py
            --var    crest_boot_data
            --output ${CREST_BOOT_HEADER}
            ${CREST_BOOT_FILE}
    DEPENDS ${CREST_BOOT_FILE}
    COMMENT "Embedding crest.boot"
    VERBATIM
  )

  add_custom_target(CrestBootHeader DEPENDS ${CREST_BOOT_HEADER})
  add_dependencies(ChezBootHeaders CrestBootHeader)

  message(STATUS "CREST: Scheme boot embedding enabled (CREST_EMBED_SCHEME_BOOT=ON)")
else()
  message(STATUS "CREST: Scheme boot embedding disabled — use -DCREST_EMBED_SCHEME_BOOT=ON for deployment")
endif()
