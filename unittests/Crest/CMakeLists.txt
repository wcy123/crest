add_crest_unittest(CrestInferTypeTests
  InferTypeTest.cpp
)

target_link_libraries(CrestInferTypeTests
  PRIVATE
    CrestPasses
)

# The test loads the bld dialect of the op-builders tests; its compiled libraries go to this build directory.
target_compile_definitions(CrestInferTypeTests
  PRIVATE
    CREST_TEST_DIALECT_DIR="${CMAKE_SOURCE_DIR}/test/dsl/op-builders"
    CREST_TEST_SCHEME_BINARY_DIR="${CMAKE_CURRENT_BINARY_DIR}/scheme"
)
