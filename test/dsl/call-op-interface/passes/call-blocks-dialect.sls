#!r6rs
;; Like call-dialect, but the inliner interface says when it is asked to handle the terminator of
;; a block of a callee that has more than one block, and the handler leaves it as it is.
(library (passes call-blocks-dialect)
  (export callblocks)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Value)
          (mlir IR Operation)
          (mlir IR BuiltinAttributes)
          (only (mlir IR SymbolInterfaces) mlir::SymbolOpInterface)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces) mlir::CallOpInterface mlir::CallableOpInterface mlir::ArgAndResultAttrsOpInterface mlir::CallInterfaceCallable::get<SymbolRefAttr> mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr> crest::OperandRange::get)
          (only (mlir IR BuiltinTypes) mlir::FunctionType::getInputs mlir::FunctionType::getResults)
          (only (mlir Transforms InliningUtils) mlir::DialectInlinerInterface))

  (define-dialect callblocks
    (:interfaces ((mlir::DialectInlinerInterface
                   (isLegalToInline/call   (call callable wouldBeCloned) #t)
                   (isLegalToInline/region (dest src wouldBeCloned) #t)
                   (isLegalToInline/op     (op dest wouldBeCloned) #t)
                   (handleTerminator/value (op replacements) #f)
                   (handleTerminator/block (op new-dest)
                                           (display "handleTerminator/block\n"
                                                    (current-output-port))
                                           (flush-output-port (current-output-port)))
                   (materializeCallConversion (builder input result-type loc) 0))))
    (define-op func
      :summary    "function"
      :interfaces ((mlir::SymbolOpInterface)
                   (mlir::ArgAndResultAttrsOpInterface :standard)
                   (mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self)
                                      (mlir::FunctionType::getInputs
                                       (mlir::TypeAttr::getValue (mlir::Operation::getAttr self "function_type"))))
                    (getResultTypes (self)
                                    (mlir::FunctionType::getResults
                                     (mlir::TypeAttr::getValue (mlir::Operation::getAttr self "function_type")))))
                   (mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (mlir::TypeAttr::getValue (mlir::Operation::getAttr self "function_type")))
                    (setFunctionTypeAttr (self attr)
                                         (mlir::Operation::setAttr! self "function_type" attr)))))
    (define-op call
      :summary    "call a function by symbol name"
      :results    ((output mlir::Value?))
      :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)
                   (mlir::CallOpInterface
                    (getCallableForCallee (self)
                                          (mlir::CallInterfaceCallable::get<SymbolRefAttr>
                                           (mlir::Operation::getAttr self "callee")))
                    (setCalleeFromCallable (self callee)
                                           (mlir::Operation::setAttr!
                                            self "callee"
                                            (mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr> callee)))
                    (getArgOperands (self)
                                    (crest::OperandRange::get self 0 (mlir::Operation::getNumOperands self)))
                    (getArgOperandsMutable :all-operands))))
    (define-op ret
      :summary "return from callblocks.func"
      :traits (terminator))))
