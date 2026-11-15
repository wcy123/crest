##
# cmake/check-llvm-version.cmake — stop early when LLVM is a version that CREST does not support
#
# Included by CMakeLists.txt after find_package(LLVM). LLVM_VERSION and LLVM_DIR are the ones that find_package set.
# It can also run alone, for a test: cmake -DLLVM_VERSION=21.1.0 -DLLVM_DIR=... -P cmake/check-llvm-version.cmake
#
# CREST builds with LLVM and MLIR 22 and 23 (CI builds both). An older one fails far from the cause (a missing header
# or a changed signature in the middle of the build), so it is refused here; a newer one is tried with a warning.
##

if(NOT DEFINED LLVM_VERSION)
  message(FATAL_ERROR "CREST: LLVM_VERSION is not set; find_package(LLVM) must come before this file")
endif()

string(REGEX MATCH "^[0-9]+" _crest_llvm_major "${LLVM_VERSION}")
if(_crest_llvm_major LESS 22)
  message(FATAL_ERROR
    "CREST needs LLVM and MLIR 22 or 23, but found LLVM ${LLVM_VERSION} in ${LLVM_DIR}. "
    "Point -DLLVM_DIR and -DMLIR_DIR at a 22 or 23 install (docs/getting-started.md).")
elseif(_crest_llvm_major GREATER 23)
  message(WARNING
    "CREST is tested with LLVM and MLIR 22 and 23; found LLVM ${LLVM_VERSION} in ${LLVM_DIR}. "
    "It may not build.")
endif()
