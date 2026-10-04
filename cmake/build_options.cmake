##
# cmake/build_options.cmake — CREST compiler options and warnings
#
# CREST_WARNINGS_AS_ERRORS defaults ON for standalone builds.
# Downstream projects that include crest via add_subdirectory() can
# override it before the subdirectory is added:
#   set(CREST_WARNINGS_AS_ERRORS OFF)
#   add_subdirectory(crest)
##

option(CREST_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" ON)

if(CREST_WARNINGS_AS_ERRORS)
  add_compile_options(
    $<$<CXX_COMPILER_ID:MSVC>:/W4>
    $<$<CXX_COMPILER_ID:MSVC>:/WX>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wall>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wextra>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Werror>
  )
endif()
