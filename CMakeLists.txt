cmake_minimum_required(VERSION 3.20)

# Guard project() so it only fires when crest is the root project.
# A nested project() call resets CMAKE_PROJECT_NAME and can interfere
# with find_package VERSION behaviour in the parent.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(crest VERSION 0.1.0 LANGUAGES C CXX)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(MLIR REQUIRED CONFIG)
find_package(LLVM REQUIRED CONFIG)

message(STATUS "CREST: Using MLIR ${MLIR_VERSION} in: ${MLIR_DIR}")
message(STATUS "CREST: Using LLVM ${LLVM_VERSION} in: ${LLVM_DIR}")

list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}")
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")

include(TableGen)
include(AddLLVM)
include(AddMLIR)

# LLVM/MLIR headers are set as SYSTEM so their warnings are suppressed.
# These are scoped to the directory so they don't leak into the parent project.
include_directories(SYSTEM ${LLVM_INCLUDE_DIRS})
include_directories(SYSTEM ${MLIR_INCLUDE_DIRS})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/include)

# All user-visible options (must come before build_options and deps)
include(cmake/crest-options.cmake)

# Compiler options and warnings
include(cmake/build_options.cmake)

# Third-party dependencies: ChezScheme (fetch + build) and rime (fetch)
include(cmake/deps.cmake)

# CREST Scheme libraries (interpreted at runtime — no build step)
set(CREST_SCHEME_DIR "${CMAKE_CURRENT_SOURCE_DIR}/scheme"
    CACHE PATH "CREST Scheme library root")

# C++ libraries
add_subdirectory(lib)

# Tools, tests, and unit tests are only built when crest is the root project.
# When used as a subdirectory, the parent doesn't want crest-opt or test suites.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  add_subdirectory(tools)
  add_subdirectory(test)
  add_subdirectory(unittests)
endif()
