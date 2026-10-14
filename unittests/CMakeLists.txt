##
# CREST GoogleTest unit tests
#
# Uses system GTest (libgtest-dev) on Linux or a user-provided GTest on
# Windows.  When GTest is not found the unit-test tree is skipped silently
# so that the Windows self-hosted runner (which has no GTest installed)
# does not fail cmake configure.
##

find_package(GTest QUIET)
if(NOT GTest_FOUND)
  message(STATUS "CREST: GTest not found — skipping unittests")
  return()
endif()

# add_crest_unittest: build a GoogleTest binary linked against system GTest.
function(add_crest_unittest test_name)
  add_executable(${test_name} ${ARGN})
  target_link_libraries(${test_name}
    PRIVATE
      GTest::GTest
      GTest::Main
  )
  add_test(NAME ${test_name} COMMAND ${test_name})
endfunction()

add_subdirectory(Interpreter)
