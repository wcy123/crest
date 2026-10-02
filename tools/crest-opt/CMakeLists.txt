add_llvm_executable(crest-opt crest-opt.cpp)

target_link_libraries(crest-opt
  PRIVATE
    CrestPasses
    MLIROptLib
    MLIRPass
    MLIRIR
    MLIRSupport
    MLIRFuncDialect
    MLIRShapeDialect
    MLIRTensorDialect
    MLIRTransforms
)

llvm_update_compile_flags(crest-opt)
mlir_check_all_link_libraries(crest-opt)
