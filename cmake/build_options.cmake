##
# cmake/build_options.cmake — CREST compiler options and warnings
##

option(CREST_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" ON)

if(CREST_WARNINGS_AS_ERRORS)
  add_compile_options(
    $<$<CXX_COMPILER_ID:MSVC>:/W4;/WX>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wall;-Wextra;-Werror>
  )
endif()
