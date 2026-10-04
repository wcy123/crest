##
# cmake/build_options.cmake — CREST compiler options and warnings
#
# CREST_WARNINGS_AS_ERRORS defaults OFF so that downstream projects that
# include crest via add_subdirectory() are not forced to compile with
# -Werror. Set to ON explicitly when building crest standalone.
##

option(CREST_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)

if(CREST_WARNINGS_AS_ERRORS)
  add_compile_options(
    $<$<CXX_COMPILER_ID:MSVC>:/W4>
    $<$<CXX_COMPILER_ID:MSVC>:/WX>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wall>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wextra>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Werror>
  )
endif()
