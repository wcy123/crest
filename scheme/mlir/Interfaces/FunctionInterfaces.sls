#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces)
  (export mlir::function_interface_impl::parseFunctionOp
          mlir::OperationName::getStringRef
          crest::FunctionOpInterface::getInterfaceID
          crest::SymbolOpInterface::getInterfaceID
          crest::ArgAndResultAttrsOpInterface::getInterfaceID
          crest::CallableOpInterface::getInterfaceID
          crest::FunctionOpInterface::getConcept
          mlir::function_interface_impl::printFunctionOp)
  (import (rnrs)
          (mlir Interfaces FunctionInterfaces ffi))

  (define mlir::function_interface_impl::parseFunctionOp
    %mlir::function_interface_impl::parseFunctionOp)

  (define mlir::OperationName::getStringRef
    %mlir::OperationName::getStringRef)

  (define crest::FunctionOpInterface::getInterfaceID
    %crest::FunctionOpInterface::getInterfaceID)

  (define crest::SymbolOpInterface::getInterfaceID
    %crest::SymbolOpInterface::getInterfaceID)

  (define crest::ArgAndResultAttrsOpInterface::getInterfaceID
    %crest::ArgAndResultAttrsOpInterface::getInterfaceID)

  (define crest::CallableOpInterface::getInterfaceID
    %crest::CallableOpInterface::getInterfaceID)

  (define crest::FunctionOpInterface::getConcept
    %crest::FunctionOpInterface::getConcept)

  (define mlir::function_interface_impl::printFunctionOp
    %mlir::function_interface_impl::printFunctionOp)

  ) ;; end library (mlir Interfaces FunctionInterfaces)
