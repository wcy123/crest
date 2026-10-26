##
# CREST Bindings - Chez Scheme / MLIR integration
#
# CrestBindings owns the Chez Scheme build artifacts (scheme.h, libkernel.a,
# liblz4.a, libz.a). CrestInterpreter and other targets get them transitively.
##

add_library(CrestBindings STATIC
  MainModule.cpp
  $<TARGET_OBJECTS:CrestCore>
  
  
  Dialect/Shape/IR/Shape.cpp
  Dialect/Shape/IR/Shape.h
  Dialect/Tensor/IR/Tensor.cpp
  Dialect/Tensor/IR/Tensor.h
  Interfaces/CallInterfaces.cpp
  Interfaces/CallInterfaces.h
  Interfaces/DestinationStyleOpInterface.cpp
  Interfaces/DestinationStyleOpInterface.h
  Interfaces/FunctionInterfaces.cpp
  Interfaces/FunctionInterfaces.h
  IR/SymbolTable.cpp
  IR/SymbolTable.h
  IR/Block.cpp
  IR/Block.h
  IR/BuiltinAttributes.cpp
  IR/BuiltinAttributes.h
  IR/BuiltinOps.cpp
  IR/BuiltinOps.h
  IR/BuiltinTypes.cpp
  IR/BuiltinTypes.h
  IR/Location.cpp
  IR/Location.h
  IR/MLIRContext.cpp
  IR/OpImplementation.cpp
  IR/OpImplementation.h
  IR/MLIRContext.h
  IR/Builders.cpp
  IR/Builders.h
  IR/Operation.cpp
  IR/Operation.h
  IR/OperationSupport.cpp
  IR/OperationSupport.h
  
  
  IR/PatternMatch.cpp
  IR/PatternMatch.h
  IR/Region.cpp
  IR/Region.h
  IR/Types.cpp
  IR/Types.h
  IR/Value.cpp
  IR/Value.h
  Support/ArrayRef.cpp
  Support/ArrayRef.h
  Support/CrestObject.cpp
  Support/CrestObject.h
  Support/LockedSchemeObject.cpp
  Support/LockedSchemeObject.h
  Support/Logging.cpp
  Support/Logging.h
  Support/SchemeWrapper.cpp
  Support/SchemeWrapper.h
  Transforms/DialectConversion.cpp
  Transforms/DialectConversion.h
  Transforms/GreedyPatternRewriteDriver.cpp
  Transforms/GreedyPatternRewriteDriver.h
)

add_dependencies(CrestBindings ChezScheme ChezBootHeaders)

target_include_directories(CrestBindings
  PUBLIC
    ${ChezScheme_BINARY_DIR}/${CHEZ_MACHINE}  # scheme.h
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..            # lib/ - allows Crest/ to include Bindings/Support/
)

target_link_libraries(CrestBindings
  PUBLIC
    MLIRIR
    MLIRFuncDialect
    MLIRCallInterfaces
    MLIRFunctionInterfaces
    MLIRTensorDialect
    MLIRShapeDialect
    MLIRTransforms
    MLIRDialectUtils
    MLIRTransformUtils
    ${CHEZ_KERNEL_LIB}
    ${CHEZ_ZLIB_LIB}
    ${CHEZ_LZ4_LIB}
)

if(WIN32)
  # build.bat /exe compiles the kernel with /DSCHEME_STATIC. The same
  # macro must be set here so scheme.h does not dllimport those symbols.
  target_compile_definitions(CrestBindings PUBLIC SCHEME_STATIC)
  target_link_libraries(CrestBindings
    PUBLIC
      rpcrt4
      ole32
      advapi32
      user32
  )
else()
  target_link_libraries(CrestBindings
    PUBLIC
      ${CMAKE_DL_LIBS}
      m
      pthread
      ncurses
  )
endif()
