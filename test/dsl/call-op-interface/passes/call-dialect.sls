#!r6rs
;; A Scheme dialect whose func and call ops are what MLIR's inliner needs: calltest.func is a
;; FunctionOpInterface (which brings the symbol and callable interfaces), calltest.call is a
;; CallOpInterface, and the dialect says that inlining is legal. calltest.ret ends the function.
(library (passes call-dialect)
  (export calltest)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinAttributes)
          (mlir IR Operation)
          (only (mlir IR SymbolInterfaces) mlir::SymbolOpInterface)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces) mlir::CallOpInterface mlir::CallableOpInterface mlir::ArgAndResultAttrsOpInterface mlir::CallInterfaceCallable::get<SymbolRefAttr> mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr> crest::OperandRange::get)
          (only (mlir IR BuiltinTypes) mlir::FunctionType::getInputs mlir::FunctionType::getResults)
          (only (mlir Transforms InliningUtils) mlir::DialectInlinerInterface)
          (only (crest support array-ref) crest::CArrayRef::size crest::CArrayRef::at))

  (define-dialect calltest
    (:interfaces ((mlir::DialectInlinerInterface
                   (isLegalToInline/call   (call callable wouldBeCloned) #t)
                   (isLegalToInline/region (dest src wouldBeCloned) #t)
                   (isLegalToInline/op     (op dest wouldBeCloned) #t)
                   (handleTerminator/value (op replacements)
                                           (do ([i 0 (+ i 1)])
                                               ((= i (crest::CArrayRef::size replacements)))
                                             (mlir::Value::replaceAllUsesWith
                                              (crest::CArrayRef::at replacements i)
                                              (mlir::Operation::getOperand op i))))
                   (handleTerminator/block (op new-dest) #f)
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
      :summary "return from calltest.func"
      :traits (terminator))))
