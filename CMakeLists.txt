##
# CREST third-party dependencies via CMake FetchContent.
# These are fetched at configure time and cached in the build tree.
# Requires network on first configure; subsequent configures use the cache.
##

cmake_minimum_required(VERSION 3.20)

include(FetchContent)

# ChezScheme — Chez Scheme runtime
# GIT_SUBMODULES_RECURSE populates zuo, zlib, lz4, nanopass, stex automatically.
FetchContent_Declare(ChezScheme
  GIT_REPOSITORY        https://github.com/cisco/ChezScheme.git
  GIT_TAG               e95a7efbafa2cf3bd5343ea542e6bc909a7ab2c4
  GIT_SUBMODULES_RECURSE TRUE
  GIT_PROGRESS          TRUE
)
FetchContent_GetProperties(ChezScheme)
if(NOT chezscheme_POPULATED)
  FetchContent_Populate(ChezScheme)
endif()
set(ChezScheme_SOURCE_DIR "${chezscheme_SOURCE_DIR}" CACHE INTERNAL "")

# rime — pure Scheme loop / iteration library (no build step)
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
