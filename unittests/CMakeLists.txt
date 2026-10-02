##
# CREST GoogleTest unit tests
##

# Umbrella target required by LLVM's add_unittest helper
add_custom_target(CrestUnitTests)

# add_crest_unittest: thin wrapper around add_unittest that attaches to the
# CrestUnitTests umbrella. Usage:
#   add_crest_unittest(TargetName Source1.cpp ...)
function(add_crest_unittest test_name)
  add_unittest(CrestUnitTests ${test_name} ${ARGN})
endfunction()

add_subdirectory(Interpreter)
