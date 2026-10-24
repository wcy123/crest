#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces ffi)
  (export %mlir::function_interface_impl::parseFunctionOp
          %crest::FunctionOpInterface::registerConcept
          %crest::FunctionOpInterface::default::getFunctionType
          %crest::FunctionOpInterface::default::setFunctionTypeAttr
          %crest::FunctionOpInterface::default::verifyBody
          %crest::FunctionOpInterface::default::verifyType
          %mlir::function_interface_impl::printFunctionOp)
  (import (chezscheme))

  ;; Register the interface concept for an op.
  ;; op-name: string, scheme-proc: uptr (dispatch procedure or 0 for C++ default).
  (define %crest::FunctionOpInterface::registerConcept
    (foreign-procedure "crest::FunctionOpInterface::registerConcept" (string uptr) void))

  ;; Default C++ implementations — called by the mlir::FunctionOpInterface
  ;; Scheme procedure for optional methods.
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
