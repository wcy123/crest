cmake_minimum_required(VERSION 3.20)
project(crest VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Third-party dependencies: ChezScheme (fetch + build) and rime (fetch)
include(cmake/deps.cmake)
