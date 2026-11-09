#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces ffi)
  (export %mlir::FunctionOpInterface
          %crest::FunctionOpInterface::reportFailure
          %mlir::function_interface_impl::parseFunctionOp
          %mlir::function_interface_impl::printFunctionOp
          %mlir::FunctionOpInterface::getFunctionType
          %mlir::FunctionOpInterface::setFunctionTypeAttr
          %mlir::FunctionOpInterface::verifyBody
          %mlir::FunctionOpInterface::verifyType)
  (import (chezscheme))

  ;; Register the interface concept of one op: its name, then the entry point of the
  ;; foreign-callable of each method (getFunctionType, setFunctionTypeAttr, cloneTypeWith,
  ;; verifyBody, verifyType), 0 for a method the op leaves to the default.
  (define %mlir::FunctionOpInterface
    (foreign-procedure "mlir::FunctionOpInterface" (string uptr uptr uptr uptr uptr) void))

  ;; The text of an error that a verifier raised, for the diagnostic that its failure makes.
  (define %crest::FunctionOpInterface::reportFailure
    (foreign-procedure "crest::FunctionOpInterface::reportFailure" (string) void))

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
