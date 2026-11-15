add_crest_unittest(CrestInterpreterTests
  InterpreterTest.cpp
  SupportTest.cpp
)

target_link_libraries(CrestInterpreterTests
  PRIVATE
    CrestPasses
)
