##
# CrestInterpreter — Chez Scheme runtime wrapper
#
# Builds ChezScheme from source via ExternalProject_Add, embeds the
# resulting .boot files as C headers, then compiles CrestInterpreter.
##

include(ExternalProject)
find_package(Python3 COMPONENTS Interpreter REQUIRED)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "Chez Scheme integration requires 64-bit architecture")
endif()

if(WIN32)
  set(CHEZ_MACHINE "ta6nt")
else()
  set(CHEZ_MACHINE "ta6le")
endif()

message(STATUS "Chez Scheme machine type: ${CHEZ_MACHINE}")

# Honour CMAKE_C_COMPILER_LAUNCHER (e.g. sccache) for ChezScheme's C build.
# ChezScheme's configure accepts CC= and zuo propagates it to all sub-builds.
if(CMAKE_C_COMPILER_LAUNCHER)
  set(CHEZ_CC "${CMAKE_C_COMPILER_LAUNCHER} ${CMAKE_C_COMPILER}")
else()
  set(CHEZ_CC "${CMAKE_C_COMPILER}")
endif()
message(STATUS "Chez Scheme CC: ${CHEZ_CC}")

ExternalProject_Add(ChezScheme
  SOURCE_DIR ${CMAKE_SOURCE_DIR}/third_party/ChezScheme
  BINARY_DIR ${CMAKE_BINARY_DIR}/ChezScheme-build
  CONFIGURE_COMMAND ${CMAKE_COMMAND} -E chdir <BINARY_DIR>
    ${CMAKE_SOURCE_DIR}/third_party/ChezScheme/configure
    --threads
    --disable-x11
    --machine=${CHEZ_MACHINE}
    CC=${CHEZ_CC}
  BUILD_COMMAND ${CMAKE_COMMAND} -E chdir <BINARY_DIR> make -j8
  INSTALL_COMMAND ""
  BUILD_BYPRODUCTS
    <BINARY_DIR>/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/petite.boot
    <BINARY_DIR>/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/scheme.boot
    <BINARY_DIR>/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/libkernel.a
    <BINARY_DIR>/${CHEZ_MACHINE}/lz4/lib/liblz4.a
    <BINARY_DIR>/${CHEZ_MACHINE}/zlib/libz.a
)

ExternalProject_Get_Property(ChezScheme SOURCE_DIR BINARY_DIR)
set(ChezScheme_SOURCE_DIR "${SOURCE_DIR}" PARENT_SCOPE)
set(ChezScheme_BINARY_DIR "${BINARY_DIR}" PARENT_SCOPE)
set(ChezScheme_SOURCE_DIR "${SOURCE_DIR}")
set(ChezScheme_BINARY_DIR "${BINARY_DIR}")
set(CHEZ_MACHINE "${CHEZ_MACHINE}" PARENT_SCOPE)

# Embed .boot files as C byte-array headers via xxd.py
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/ChezBootPetite.h
  COMMAND ${Python3_EXECUTABLE}
          ${CMAKE_SOURCE_DIR}/cmake/xxd.py
          --var petite_boot_data
          --output ${CMAKE_CURRENT_BINARY_DIR}/ChezBootPetite.h
          ${BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/petite.boot
  DEPENDS ChezScheme
  COMMENT "Embedding petite.boot"
  VERBATIM
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/ChezBootScheme.h
  COMMAND ${Python3_EXECUTABLE}
          ${CMAKE_SOURCE_DIR}/cmake/xxd.py
          --var scheme_boot_data
          --output ${CMAKE_CURRENT_BINARY_DIR}/ChezBootScheme.h
          ${BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/scheme.boot
  DEPENDS ChezScheme
  COMMENT "Embedding scheme.boot"
  VERBATIM
)

add_custom_target(ChezBootHeaders DEPENDS
  ${CMAKE_CURRENT_BINARY_DIR}/ChezBootPetite.h
  ${CMAKE_CURRENT_BINARY_DIR}/ChezBootScheme.h
)

set(ChezBootHeaders_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}" PARENT_SCOPE)

# CrestInterpreter static library
add_library(CrestInterpreter STATIC ChezSchemeInterpreter.cpp)
add_dependencies(CrestInterpreter ChezScheme ChezBootHeaders)

target_include_directories(CrestInterpreter
  PUBLIC
    ${BINARY_DIR}/${CHEZ_MACHINE}          # scheme.h
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}            # ChezSchemeInterpreter.h
    ${CMAKE_CURRENT_BINARY_DIR}            # ChezBootPetite.h, ChezBootScheme.h
    ${SOURCE_DIR}/boot/pb                  # pb/scheme.h fallback
)

target_compile_definitions(CrestInterpreter PRIVATE
  SCHEME_LIBRARIES_DIR="${CMAKE_SOURCE_DIR}/scheme"
  SCHEME_BINARY_DIR="${CMAKE_BINARY_DIR}/scheme"
  RIME_DIR="${CMAKE_SOURCE_DIR}/third_party/rime"
)

target_link_libraries(CrestInterpreter
  PUBLIC
    MLIRIR
  PRIVATE
    ${BINARY_DIR}/${CHEZ_MACHINE}/boot/${CHEZ_MACHINE}/libkernel.a
    ${BINARY_DIR}/${CHEZ_MACHINE}/lz4/lib/liblz4.a
    ${BINARY_DIR}/${CHEZ_MACHINE}/zlib/libz.a
    ${CMAKE_DL_LIBS}
    m
    pthread
    ncurses
)
