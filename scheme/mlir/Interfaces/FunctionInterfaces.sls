#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces)
  (export mlir::function_interface_impl::parseFunctionOp
          crest::FunctionOpInterface::getInterfaceID
          crest::SymbolOpInterface::getInterfaceID
          crest::ArgAndResultAttrsOpInterface::getInterfaceID
          crest::CallableOpInterface::getInterfaceID
          crest::FunctionOpInterface::getConcept
          crest::FunctionOpInterface::setSchemeDispatch
          crest::FunctionOpInterface::getSchemeConceptPtr
          mlir::FunctionOpInterface
          mlir::function_interface_impl::printFunctionOp)
  (import (rnrs)
          (mlir Interfaces FunctionInterfaces ffi))

  (define mlir::function_interface_impl::parseFunctionOp
    %mlir::function_interface_impl::parseFunctionOp)

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

  (define crest::FunctionOpInterface::setSchemeDispatch
    %crest::FunctionOpInterface::setSchemeDispatch)

  (define crest::FunctionOpInterface::getSchemeConceptPtr
    %crest::FunctionOpInterface::getSchemeConceptPtr)

  ;; mlir::FunctionOpInterface — default Scheme dispatch procedure.
  ;; Forwards each method to the corresponding C++ default implementation in
  ;; g_function_concept.  Per-op overrides call this as their fallback via
  ;; (else (apply mlir::FunctionOpInterface method args)).
  (define (mlir::FunctionOpInterface method . args)
    (case method
      ((getFunctionType)
       (apply %crest::FunctionOpInterface::default::getFunctionType args))
      ((setFunctionTypeAttr)
       (apply %crest::FunctionOpInterface::default::setFunctionTypeAttr args))
      ((verifyBody)
       (apply %crest::FunctionOpInterface::default::verifyBody args))
      ((verifyType)
       (apply %crest::FunctionOpInterface::default::verifyType args))
      (else
       (error "mlir::FunctionOpInterface" "unknown method" method))))

  (define mlir::function_interface_impl::printFunctionOp
    %mlir::function_interface_impl::printFunctionOp)

  ) ;; end library (mlir Interfaces FunctionInterfaces)
