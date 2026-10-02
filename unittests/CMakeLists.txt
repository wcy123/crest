##
# CREST GoogleTest unit tests
##

# add_crest_unittest: thin wrapper around add_unittest that links GTest and
# sets the CREST test output folder. Usage:
#   add_crest_unittest(TargetName Source1.cpp Source2.cpp ...)
function(add_crest_unittest test_name)
  add_unittest(CrestUnitTests ${test_name} ${ARGN})
endfunction()

add_subdirectory(Interpreter)
