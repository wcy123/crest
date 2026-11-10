#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces ffi)
  (export %mlir::FunctionOpInterface::getInterfaceID
          %crest::FunctionOpInterface::reportFailure
          %mlir::function_interface_impl::parseFunctionOp
          %mlir::function_interface_impl::printFunctionOp
          %mlir::FunctionOpInterface::getFunctionType
          %mlir::FunctionOpInterface::setFunctionTypeAttr
          %mlir::FunctionOpInterface::verifyBody
          %mlir::FunctionOpInterface::verifyType)
  (import (chezscheme))

  ;; () -> uptr: the TypeID of the interface, as the address that the TypeID wraps.
  (define %mlir::FunctionOpInterface::getInterfaceID
    (foreign-procedure "mlir::FunctionOpInterface::getInterfaceID" () uptr))

  ;; The text of an error that a verifier raised, for the diagnostic that its failure makes.
  (define %crest::FunctionOpInterface::reportFailure
    (foreign-procedure "crest::FunctionOpInterface::reportFailure" (string) void))

  ;; Interface method calls — look up the concept in the interface map of the op and dispatch.
  (define %mlir::FunctionOpInterface::getFunctionType
    (foreign-procedure "mlir::FunctionOpInterface::getFunctionType" (uptr) uptr))

  (define %mlir::FunctionOpInterface::setFunctionTypeAttr
    (foreign-procedure "mlir::FunctionOpInterface::setFunctionTypeAttr" (uptr uptr) void))

  (define %mlir::FunctionOpInterface::verifyBody
    (foreign-procedure "mlir::FunctionOpInterface::verifyBody" (uptr) boolean))

  (define %mlir::FunctionOpInterface::verifyType
    (foreign-procedure "mlir::FunctionOpInterface::verifyType" (uptr) boolean))

  (define %mlir::function_interface_impl::parseFunctionOp
    (foreign-procedure "mlir::function_interface_impl::parseFunctionOp"
                       (uptr uptr) boolean))

  (define %mlir::function_interface_impl::printFunctionOp
    (foreign-procedure "mlir::function_interface_impl::printFunctionOp"
                       (uptr uptr) void))

  ) ;; end library (mlir Interfaces FunctionInterfaces ffi)
