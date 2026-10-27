#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces ffi)
  (export %mlir::FunctionOpInterface
          %mlir::function_interface_impl::parseFunctionOp
          %mlir::function_interface_impl::printFunctionOp
          %crest::FunctionOpInterface::default::getFunctionType
          %crest::FunctionOpInterface::default::setFunctionTypeAttr
          %crest::FunctionOpInterface::default::verifyBody
          %crest::FunctionOpInterface::default::verifyType
          %mlir::FunctionOpInterface::getFunctionType
          %mlir::FunctionOpInterface::setFunctionTypeAttr
          %mlir::FunctionOpInterface::verifyBody
          %mlir::FunctionOpInterface::verifyType)
  (import (chezscheme))

  ;; Register an interface concept for one op via a Scheme dispatcher procedure.
  (define %mlir::FunctionOpInterface
    (foreign-procedure "mlir::FunctionOpInterface" (scheme-object) void))

  ;; Default C++ implementations — callable from Scheme fallback dispatch.
  (define %crest::FunctionOpInterface::default::getFunctionType
    (foreign-procedure "crest::FunctionOpInterface::default::getFunctionType" (uptr) uptr))

  (define %crest::FunctionOpInterface::default::setFunctionTypeAttr
    (foreign-procedure "crest::FunctionOpInterface::default::setFunctionTypeAttr" (uptr uptr) void))

  (define %crest::FunctionOpInterface::default::verifyBody
    (foreign-procedure "crest::FunctionOpInterface::default::verifyBody" (uptr) boolean))

  (define %crest::FunctionOpInterface::default::verifyType
    (foreign-procedure "crest::FunctionOpInterface::default::verifyType" (uptr) boolean))

  ;; Interface method calls — look up registered concept and dispatch.
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
