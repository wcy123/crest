add_llvm_executable(scheme-mlir scheme-mlir.cpp)

target_link_libraries(scheme-mlir
  PRIVATE
    CrestPasses
    MLIRParser
    MLIRSupport
)

llvm_update_compile_flags(scheme-mlir)
mlir_check_all_link_libraries(scheme-mlir)
