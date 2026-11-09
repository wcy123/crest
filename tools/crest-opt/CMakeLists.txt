add_llvm_executable(crest-opt crest-opt.cpp)

target_link_libraries(crest-opt
  PRIVATE
    CrestPasses
    MLIROptLib
    MLIRPass
    MLIRIR
    MLIRSupport
    MLIRAffineDialect
    MLIRArithDialect
    MLIRControlFlowDialect
    MLIRFuncDialect
    MLIRLLVMDialect
    MLIRMemRefDialect
    MLIRSCFDialect
    MLIRShapeDialect
    MLIRTensorDialect
    MLIRTransforms
)

llvm_update_compile_flags(crest-opt)
mlir_check_all_link_libraries(crest-opt)

# EXPERIMENT (to be reverted): a linker map, to symbolize a crash on Windows.
if(MSVC)
  target_link_options(crest-opt PRIVATE /MAP)
endif()
