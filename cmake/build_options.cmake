##
# cmake/build_options.cmake — CREST compiler options and warnings
##

option(CREST_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" ON)

if(CREST_WARNINGS_AS_ERRORS)
  add_compile_options(
    $<$<CXX_COMPILER_ID:MSVC>:/W4>
    $<$<CXX_COMPILER_ID:MSVC>:/WX>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wall>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wextra>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Werror>
    # -Wunused-parameter is too noisy in LLVM/MLIR template-heavy headers
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wno-unused-parameter>
  )
endif()
