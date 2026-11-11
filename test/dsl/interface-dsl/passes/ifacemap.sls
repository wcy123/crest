#!r6rs
;; A dialect with one op per interface of the :interfaces clause, and one with none: the ops of
;; unittests/Crest/InterfaceTest.cpp, which asks the interface map of each what it has. The dialect
;; has an inliner interface of its own (the :interfaces clause of the dialect).
(library (passes ifacemap)
  (export ifacemap)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (mlir IR BuiltinAttributes)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces)
                mlir::CallableOpInterface mlir::CallOpInterface mlir::ArgAndResultAttrsOpInterface mlir::CallInterfaceCallable::get<SymbolRefAttr> mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr> crest::OperandRange::get)
          (only (mlir IR SymbolInterfaces) mlir::SymbolOpInterface)
          (only (mlir Transforms InliningUtils) mlir::DialectInlinerInterface)
          (only (mlir Interfaces SideEffectInterfaces)
                mlir::MemoryEffectOpInterface mlir::ConditionallySpeculatable))

  (define-dialect ifacemap
    (:interfaces ((mlir::DialectInlinerInterface
                   (isLegalToInline/call   (call callable would-be-cloned) #t)
                   (isLegalToInline/region (dest src would-be-cloned) #t)
                   (isLegalToInline/op     (op dest would-be-cloned) #t))))
    (define-op func
      :interfaces ((mlir::SymbolOpInterface)
                   (mlir::ArgAndResultAttrsOpInterface :standard)
                   (mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))
                   (mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (mlir::TypeAttr::getValue
                                      (mlir::Operation::getAttr self "function_type")))
                    (setFunctionTypeAttr (self attr)
                                         (mlir::Operation::setAttr! self "function_type" attr)))))
    (define-op callee
      :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)
                   (mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))))
    (define-op call   :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)
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
    (define-op attrs  :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)))
    (define-op symbol :interfaces ((mlir::SymbolOpInterface)))
    (define-op effect :interfaces ((mlir::MemoryEffectOpInterface) (mlir::ConditionallySpeculatable)))
    (define-op bare)))
