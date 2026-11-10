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

add_crest_unittest(CrestInterfaceTests
  InterfaceTest.cpp
)

target_link_libraries(CrestInterfaceTests
  PRIVATE
    CrestPasses
)

# The test loads the ifacemap dialect of the interface-dsl tests.
target_compile_definitions(CrestInterfaceTests
  PRIVATE
    CREST_TEST_DIALECT_DIR="${CMAKE_SOURCE_DIR}/test/dsl/interface-dsl"
    CREST_TEST_SCHEME_BINARY_DIR="${CMAKE_CURRENT_BINARY_DIR}/scheme-interface"
)
