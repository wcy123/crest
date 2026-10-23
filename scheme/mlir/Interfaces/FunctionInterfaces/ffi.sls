#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces ffi)
  (export %mlir::function_interface_impl::parseFunctionOp
          %crest::FunctionOpInterface::getInterfaceID
          %crest::SymbolOpInterface::getInterfaceID
          %crest::ArgAndResultAttrsOpInterface::getInterfaceID
          %crest::CallableOpInterface::getInterfaceID
          %crest::FunctionOpInterface::getConcept
          %mlir::function_interface_impl::printFunctionOp)
  (import (chezscheme))

  (define %crest::FunctionOpInterface::getInterfaceID
    (foreign-procedure "crest::FunctionOpInterface::getInterfaceID" () uptr))

  (define %crest::SymbolOpInterface::getInterfaceID
    (foreign-procedure "crest::SymbolOpInterface::getInterfaceID" () uptr))

  (define %crest::ArgAndResultAttrsOpInterface::getInterfaceID
    (foreign-procedure "crest::ArgAndResultAttrsOpInterface::getInterfaceID" () uptr))

  (define %crest::CallableOpInterface::getInterfaceID
    (foreign-procedure "crest::CallableOpInterface::getInterfaceID" () uptr))

  (define %crest::FunctionOpInterface::getConcept
    (foreign-procedure "crest::FunctionOpInterface::getConcept" (uptr) uptr))

  (define %mlir::function_interface_impl::parseFunctionOp
    (foreign-procedure "mlir::function_interface_impl::parseFunctionOp"
                       (uptr uptr) boolean))

  (define %mlir::function_interface_impl::printFunctionOp
    (foreign-procedure "mlir::function_interface_impl::printFunctionOp"
                       (uptr uptr) void))

  ) ;; end library (mlir Interfaces FunctionInterfaces ffi)
