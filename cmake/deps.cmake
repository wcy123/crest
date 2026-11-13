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
# Pin: d533f2e156d4eddeafe24bd7cc4de87fdc88caeb, committed 2026-11-07 (Chez Scheme 10.5.0), the
# newest commit of cisco/ChezScheme main when the pin was moved (2026-11-10); the previous pin was
# e95a7ef, 2026-05-11 (10.4.1). Why it moved: cisco/ChezScheme#1064, merged 2026-09-17, repairs
# "Windows x64: XMM register preservation by callables". Before it, the entry and exit code of a
# foreign-callable saved XMM6-XMM11 as 64-bit doubles and the restore zeroed their upper halves,
# which that ABI makes callee-saved, so MLIR code that keeps a 16-byte value there across a call
# into a callable (LLVM 23: Block::iterator) saw it change. The newest commit was taken, not the
# merge of #1064 alone, to get the other repairs since (e.g. x86_64 foreign call and callable
# arguments); the commit titles after #1064 show no revert. Details and the steps to bump the pin again:
# docs/tech-note.md, "Chez Scheme pin".
# LEAK WARNING: Chez 10.5.0 (upstream main too) leaks about 208 bytes every time a Scheme error escapes
# through a C function that had called into Scheme (a C++ binding that raises, or a callback that raises
# and is caught by a guard outside it). The cause is one line in S_call_help (c/schlib.c). We do NOT
# patch Chez: cmake/patches/chez-release-escaped-frames.patch is kept for the record (it explains the
# leak, has a standalone repro in cmake/patches/chez-error-escape-leak/, and says what is known about
# upstream and how sure we are), and it is not applied by this build. CREST avoids the leak instead by
# never letting an error cross a C function: CLAUDE.md Rule 20.
FetchContent_Declare(ChezScheme
  GIT_REPOSITORY         https://github.com/cisco/ChezScheme.git
  GIT_TAG                d533f2e156d4eddeafe24bd7cc4de87fdc88caeb
  GIT_SUBMODULES_RECURSE TRUE
  GIT_PROGRESS           TRUE
)
FetchContent_GetProperties(ChezScheme)
if(NOT chezscheme_POPULATED)
  FetchContent_Populate(ChezScheme)
endif()
set(ChezScheme_SOURCE_DIR "${chezscheme_SOURCE_DIR}" CACHE INTERNAL "")

# CHEZ_BUILD_DIR: redirect the ChezScheme build tree outside CMAKE_BINARY_DIR
# so compiled artifacts survive a cmake clean / rmdir build between CI runs.
# Windows CI sets -DCHEZ_BUILD_DIR=C:/Develop/crest-deps/<pin>/chezscheme-build, a directory per
# pin (see docs/tech-note.md, "Chez Scheme pin").
# Linux CI uses actions/cache to restore the default in-tree location.
if(DEFINED CHEZ_BUILD_DIR)
  set(ChezScheme_BINARY_DIR "${CHEZ_BUILD_DIR}" CACHE INTERNAL "" FORCE)
  # Keep ExternalProject stamps alongside the build dir so they also survive.
  # Named after the build directory: a new build directory (CI names it after
  # the pin, so a bump of GIT_TAG builds Chez again) must not find the stamps of
  # the old one and skip its build.
  set(_chez_stamp_dir "${CHEZ_BUILD_DIR}-stamp")
else()
  set(ChezScheme_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/ChezScheme-build" CACHE INTERNAL "")
  set(_chez_stamp_dir "${CMAKE_CURRENT_BINARY_DIR}/ChezScheme-prefix/src/ChezScheme-stamp")
endif()

# ─── ChezScheme: build ────────────────────────────────────────────────────────
# Windows uses Chez's MSVC build.bat (machine ta6nt). /exe asks for a static
# kernel. /MT matches LLVM's CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded, which
# this tree's LLVMConfig.cmake applies to every consumer. Unix keeps
# configure + make.
if(WIN32)
  # csv1050.lib = Chez Scheme 10.5.0, pinned at GIT_TAG d533f2e. Update when bumping GIT_TAG.
  set(CHEZ_KERNEL_LIB "${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/csv1050.lib" CACHE INTERNAL "" FORCE)
  set(CHEZ_ZLIB_LIB   "${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/zlibmts/zlib.lib"                 CACHE INTERNAL "" FORCE)
  set(CHEZ_LZ4_LIB    "${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/lz4mts/lib/liblz4.lib"            CACHE INTERNAL "" FORCE)
  # cmd /c: CreateProcess cannot launch a .bat. cmake -E true is a no-op
  # configure step; an empty one is dropped, and ExternalProject then runs cmake on Chez, which has no CMakeLists.txt.
  set(_chez_configure ${CMAKE_COMMAND} -E true)
  # /keepvs: skip build.bat's own VS detection — vcvars64.bat was already
  # sourced by the caller (CI step or developer prompt) before cmake runs.
  set(_chez_build
    ${CMAKE_COMMAND} -E chdir <BINARY_DIR>
      cmd /c ${ChezScheme_SOURCE_DIR}/build.bat ${CHEZ_MACHINE} /exe /MT /only /keepvs)
else()
  set(CHEZ_KERNEL_LIB "${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/libkernel.a" CACHE INTERNAL "")
  set(CHEZ_ZLIB_LIB   "${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/zlib/libz.a"                      CACHE INTERNAL "")
  set(CHEZ_LZ4_LIB    "${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/lz4/lib/liblz4.a"                 CACHE INTERNAL "")
  set(_chez_configure
    ${CMAKE_COMMAND} -E chdir <BINARY_DIR>
      ${ChezScheme_SOURCE_DIR}/configure
        --threads --disable-x11 --machine=${CHEZ_MACHINE} CC=${CHEZ_CC})
  set(_chez_build
    ${CMAKE_COMMAND} -E chdir <BINARY_DIR> make -j8)
endif()

ExternalProject_Add(ChezScheme
  SOURCE_DIR        ${ChezScheme_SOURCE_DIR}
  BINARY_DIR        ${ChezScheme_BINARY_DIR}
  STAMP_DIR         ${_chez_stamp_dir}
  CONFIGURE_COMMAND ${_chez_configure}
  BUILD_COMMAND     ${_chez_build}
  INSTALL_COMMAND   ""
  BUILD_BYPRODUCTS
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/petite.boot
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/scheme.boot
    ${CHEZ_KERNEL_LIB}
    ${CHEZ_ZLIB_LIB}
    ${CHEZ_LZ4_LIB}
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
  # The boot file itself, not only the ChezScheme target: a target gives no file-level dependency,
  # so after a new GIT_TAG an existing build tree kept embedding the old boot file
  # ("petite.boot is for Version 10.4.1; need Version 10.5.0").
  DEPENDS ChezScheme ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/petite.boot
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
  # The boot file itself, not only the ChezScheme target: a target gives no file-level dependency,
  # so after a new GIT_TAG an existing build tree kept embedding the old boot file
  # ("petite.boot is for Version 10.4.1; need Version 10.5.0").
  DEPENDS ChezScheme ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/scheme.boot
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

  file(GLOB_RECURSE CREST_SLS_FILES
       "${CMAKE_CURRENT_SOURCE_DIR}/scheme/*.sls"
       "${CMAKE_CURRENT_SOURCE_DIR}/samples/*.sls")

  # ── Extensible source dirs and root libraries ─────────────────────────────────
  # Downstream projects can extend these lists BEFORE add_subdirectory(crest):
  #   list(PREPEND CREST_BOOT_SOURCE_DIRS "${MY_SCHEME_DIR}")
  #   list(PREPEND CREST_BOOT_ROOTS       "${MY_SCHEME_DIR}/my-root.sls")
  #
  # CREST always appends its own entries so they're always present.
  # CREST core libraries are in scheme/; sample passes are in samples/
  list(APPEND CREST_BOOT_SOURCE_DIRS
       "${CMAKE_CURRENT_SOURCE_DIR}/scheme"
       "${CMAKE_CURRENT_SOURCE_DIR}/samples"
       "${CREST_RIME_DIR}")
  list(REMOVE_DUPLICATES CREST_BOOT_SOURCE_DIRS)

  # Default roots: the sample passes that ship with CREST.
  # Downstream projects add their own roots via CREST_BOOT_ROOTS.
  list(APPEND CREST_BOOT_ROOTS
       "${CMAKE_CURRENT_SOURCE_DIR}/samples/passes/hip-fusion.sls")
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
