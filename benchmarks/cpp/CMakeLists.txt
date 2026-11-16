add_llvm_executable(crest-bench-cpp QAddFusion.cpp)

target_link_libraries(crest-bench-cpp
  PRIVATE
    MLIROptLib
    MLIRPass
    MLIRIR
    MLIRSupport
    MLIRFuncDialect
    MLIRTensorDialect
    MLIRTransforms
)

llvm_update_compile_flags(crest-bench-cpp)
mlir_check_all_link_libraries(crest-bench-cpp)
