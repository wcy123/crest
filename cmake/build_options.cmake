##
# cmake/build_options.cmake — Apply compiler warning flags.
# Options are declared in cmake/crest-options.cmake.
##

# Match LLVM's RTTI setting. LLVM is typically built without RTTI; compiling
# CREST with RTTI while linking against an RTTI-free LLVM causes missing
# typeinfo symbols for mlir::Pass, mlir::ConversionPattern, etc.
if(NOT LLVM_ENABLE_RTTI)
  add_compile_options(
    $<$<AND:$<COMPILE_LANGUAGE:CXX>,$<CXX_COMPILER_ID:MSVC>>:/GR->
    $<$<AND:$<COMPILE_LANGUAGE:CXX>,$<NOT:$<CXX_COMPILER_ID:MSVC>>>:-fno-rtti>
  )
endif()

if(CREST_WARNINGS_AS_ERRORS)
  add_compile_options(
    $<$<CXX_COMPILER_ID:MSVC>:/W4>
    $<$<CXX_COMPILER_ID:MSVC>:/WX>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wall>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wextra>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wconversion>
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Werror>
  )
endif()

if(MSVC)
  # LLVM headers (e.g. llvm/Support/Error.h) trigger C4702 under /O2 because
  # MSVC cannot prove that [[noreturn]] callsites are unreachable. scheme_error
  # has the same issue. We cannot modify LLVM headers, so global suppression is
  # required — matching what LLVM itself does in HandleLLVMOptions.cmake.
  add_compile_options(/wd4702)
endif()
