##
# CREST GoogleTest unit tests
#
# Uses system GTest (libgtest-dev) on Linux or the GTest installed at
# C:\Develop\local on the Windows self-hosted runner.
##

find_package(GTest REQUIRED)

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
