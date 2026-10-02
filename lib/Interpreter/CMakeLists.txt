##
# CrestInterpreter — Chez Scheme runtime wrapper
##

add_library(CrestInterpreter STATIC
  ChezSchemeInterpreter.cpp
)

target_include_directories(CrestInterpreter
  PUBLIC
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${ChezBootHeaders_BINARY_DIR}
    ${ChezScheme_SOURCE_DIR}/boot/pb
)

target_link_libraries(CrestInterpreter
  PUBLIC
    MLIRIR
  PRIVATE
    ChezScheme
)
