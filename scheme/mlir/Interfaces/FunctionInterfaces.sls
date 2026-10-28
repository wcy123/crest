#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces)
  (export mlir::FunctionOpInterface
          mlir::function_interface_impl::parseFunctionOp
          mlir::function_interface_impl::printFunctionOp
          mlir::FunctionOpInterface::getFunctionType
          mlir::FunctionOpInterface::setFunctionTypeAttr
          mlir::FunctionOpInterface::verifyBody
          mlir::FunctionOpInterface::verifyType)
  (import (rnrs)
          (mlir Interfaces FunctionInterfaces ffi))

  ;; Wrapped in a lambda so callers in macro-generated code get a regular
  ;; Scheme procedure rather than a raw void-returning foreign-procedure.
  (define (mlir::FunctionOpInterface dispatcher)
    (%mlir::FunctionOpInterface dispatcher))

  (define mlir::FunctionOpInterface::getFunctionType
    %mlir::FunctionOpInterface::getFunctionType)

  (define mlir::FunctionOpInterface::setFunctionTypeAttr
    %mlir::FunctionOpInterface::setFunctionTypeAttr)

  (define mlir::FunctionOpInterface::verifyBody
    %mlir::FunctionOpInterface::verifyBody)

  (define mlir::FunctionOpInterface::verifyType
    %mlir::FunctionOpInterface::verifyType)

  (define mlir::function_interface_impl::parseFunctionOp
    %mlir::function_interface_impl::parseFunctionOp)

  (define mlir::function_interface_impl::printFunctionOp
    %mlir::function_interface_impl::printFunctionOp)

  ) ;; end library (mlir Interfaces FunctionInterfaces)
