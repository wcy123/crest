#!r6rs
;; A dialect with every kind of callback that a library makes once: the clauses of every interface, the
;; inliner interface of the dialect, the callbacks of an op and of a type, and the callbacks of the
;; dialect. test/dsl/callback-leaks/driver.sls loads it into many contexts and checks that no context
;; makes a C function of its own: they are all made when this library is loaded.
(library (passes leaks-dialect)
  (export leaks)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (mlir IR BuiltinAttributes)
          (only (mlir IR BuiltinTypes) mlir::FunctionType::get)
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces)
                mlir::CallableOpInterface mlir::CallOpInterface mlir::ArgAndResultAttrsOpInterface)
          (only (mlir IR SymbolInterfaces) mlir::SymbolOpInterface)
          (only (mlir Transforms InliningUtils) mlir::DialectInlinerInterface)
          (only (mlir Interfaces SideEffectInterfaces)
                mlir::MemoryEffectOpInterface mlir::ConditionallySpeculatable)
          (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface))

  (define-dialect leaks
    (:interfaces ((mlir::DialectInlinerInterface
                   (isLegalToInline/call   (call callable would-be-cloned) #t)
                   (isLegalToInline/region (dest src would-be-cloned) #t)
                   (isLegalToInline/op     (op dest would-be-cloned) #t)
                   (handleTerminator/value (op values) #t)
                   (handleTerminator/block (op block) #t)
                   (materializeCallConversion (builder input type loc) #f))))
    (:initialize (dialect) #t)
    (define-type simple
      (:verify (params) #t))
    (define-op func
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self) '())
                    (getResultTypes (self) '()))
                   (mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (mlir::TypeAttr::getValue
                                      (mlir::Operation::getAttr self "function_type")))
                    (verifyBody (self) #t)
                    (verifyType (self) #t)
                    (cloneTypeWith (self inputs results)
                                   (mlir::FunctionType::get (mlir::Operation::getContext self)
                                                            inputs results)))))
    (define-op call
      :interfaces ((mlir::CallOpInterface)))
    (define-op attrs
      :interfaces ((mlir::ArgAndResultAttrsOpInterface)))
    (define-op symbol
      :interfaces ((mlir::SymbolOpInterface)))
    (define-op effect
      :interfaces ((mlir::MemoryEffectOpInterface) (mlir::ConditionallySpeculatable)))
    (define-op infer
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes) '())
                    (refineReturnTypes (context location operands attributes return-types)
                                       return-types)
                    (isCompatibleReturnTypes (inferred actual) #t))))
    (define-op callbacks
      (:verify (op) #t)
      (:verify-regions (op) #t)
      (:fold (op operand-attributes) #f)
      (:populate-default-attrs (op-name attrs) #t))))
