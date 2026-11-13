#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces ffi)
  (export %mlir::FunctionOpInterface::getInterfaceID
          %mlir::function_interface_impl::parseFunctionOp
          %mlir::function_interface_impl::printFunctionOp
          %mlir::FunctionOpInterface::getFunctionType
          %mlir::FunctionOpInterface::setFunctionTypeAttr
          %mlir::FunctionOpInterface::cloneTypeWith
          %mlir::FunctionOpInterface::verifyBody
          %mlir::FunctionOpInterface::verifyType)
  (import (chezscheme)
          (crest support foreign))

  ;; () -> uptr: the TypeID of the interface, as the address that the TypeID wraps.
  (define %mlir::FunctionOpInterface::getInterfaceID
    (crest-foreign-procedure "mlir::FunctionOpInterface::getInterfaceID" () uptr))

  ;; Interface method calls — look up the concept in the interface map of the op and dispatch.
  (define %mlir::FunctionOpInterface::getFunctionType
    (crest-foreign-procedure "mlir::FunctionOpInterface::getFunctionType" (uptr) uptr))

  ;; (uptr op) (list-of-Types inputs) (list-of-Types results) -> uptr Type
  (define %mlir::FunctionOpInterface::cloneTypeWith
    (crest-foreign-procedure "mlir::FunctionOpInterface::cloneTypeWith" (uptr scheme-object scheme-object)
                             uptr))

  (define %mlir::FunctionOpInterface::setFunctionTypeAttr
    (crest-foreign-procedure "mlir::FunctionOpInterface::setFunctionTypeAttr" (uptr uptr) void))

  (define %mlir::FunctionOpInterface::verifyBody
    (crest-foreign-procedure "mlir::FunctionOpInterface::verifyBody" (uptr) ptr))

  (define %mlir::FunctionOpInterface::verifyType
    (crest-foreign-procedure "mlir::FunctionOpInterface::verifyType" (uptr) ptr))

  (define %mlir::function_interface_impl::parseFunctionOp
    (crest-foreign-procedure "mlir::function_interface_impl::parseFunctionOp"
                             (uptr uptr) ptr))

  (define %mlir::function_interface_impl::printFunctionOp
    (crest-foreign-procedure "mlir::function_interface_impl::printFunctionOp"
                             (uptr uptr) void))

  ) ;; end library (mlir Interfaces FunctionInterfaces ffi)
