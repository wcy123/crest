add_crest_unittest(CrestInterpreterTests
  InterpreterTest.cpp
)

target_link_libraries(CrestInterpreterTests
  PRIVATE
    CrestPasses
)
