#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces ffi)
  (export %mlir::function_interface_impl::parseFunctionOp
          %crest::FunctionOpInterface::getInterfaceID
          %crest::registerInterfaceForOperation
          %crest::FunctionOpInterface::default::getFunctionType
          %crest::FunctionOpInterface::default::setFunctionTypeAttr
          %crest::FunctionOpInterface::default::verifyBody
          %crest::FunctionOpInterface::default::verifyType
          %mlir::function_interface_impl::printFunctionOp)
  (import (chezscheme))

  ;; TypeID* for FunctionOpInterface — used in the dispatcher 'id clause.
  (define %crest::FunctionOpInterface::getInterfaceID
    (foreign-procedure "crest::FunctionOpInterface::getInterfaceID" () uptr))

  ;; Register an interface for one op via a Scheme dispatcher procedure.
  ;; dispatcher: scheme-object (procedure).
  (define %crest::registerInterfaceForOperation
    (foreign-procedure "crest::registerInterfaceForOperation" (scheme-object) scheme-object))

  ;; Default C++ implementations — called by mlir::FunctionOpInterface fallback.
  (define %crest::FunctionOpInterface::default::getFunctionType
    (foreign-procedure "crest::FunctionOpInterface::default::getFunctionType" (uptr) uptr))

  (define %crest::FunctionOpInterface::default::setFunctionTypeAttr
    (foreign-procedure "crest::FunctionOpInterface::default::setFunctionTypeAttr" (uptr uptr) void))

  (define %crest::FunctionOpInterface::default::verifyBody
    (foreign-procedure "crest::FunctionOpInterface::default::verifyBody" (uptr) boolean))

  (define %crest::FunctionOpInterface::default::verifyType
    (foreign-procedure "crest::FunctionOpInterface::default::verifyType" (uptr) boolean))

  (define %mlir::function_interface_impl::parseFunctionOp
    (foreign-procedure "mlir::function_interface_impl::parseFunctionOp"
                       (uptr uptr) boolean))

  (define %mlir::function_interface_impl::printFunctionOp
    (foreign-procedure "mlir::function_interface_impl::printFunctionOp"
                       (uptr uptr) void))

  ) ;; end library (mlir Interfaces FunctionInterfaces ffi)
