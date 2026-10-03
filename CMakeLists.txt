cmake_minimum_required(VERSION 3.20)
project(crest VERSION 0.1.0 LANGUAGES C CXX)

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

# Global include paths (available to all targets without repetition)
include_directories(${LLVM_INCLUDE_DIRS})
include_directories(${MLIR_INCLUDE_DIRS})
include_directories(${CMAKE_SOURCE_DIR}/include)
include_directories(${CMAKE_BINARY_DIR}/include)

# Third-party dependencies: ChezScheme (fetch + build) and rime (fetch)
include(cmake/deps.cmake)

# CREST Scheme libraries (interpreted at runtime — no build step)
set(CREST_SCHEME_DIR "${CMAKE_CURRENT_SOURCE_DIR}/scheme"
    CACHE PATH "CREST Scheme library root")

# Public headers and tablegen targets (must precede lib/)
add_subdirectory(include)

# C++ libraries
add_subdirectory(lib)

# Driver tools (crest-opt, ...)
add_subdirectory(tools)

# lit / FileCheck integration tests
add_subdirectory(test)

# GoogleTest unit tests
add_subdirectory(unittests)
