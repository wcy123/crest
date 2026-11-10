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
          (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface)
          (only (mlir Interfaces CallInterfaces) mlir::CallOpInterface)
          (only (mlir support array-ref) crest::CArrayRef::size crest::CArrayRef::at))

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
      :interface2 ((mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (mlir::TypeAttr::getValue (mlir::Operation::getAttr self "function_type")))
                    (setFunctionTypeAttr (self attr)
                                         (mlir::Operation::setAttr! self "function_type" attr)))))
    (define-op call
      :summary    "call a function by symbol name"
      :results    ((output mlir::Value?))
      :interface2 ((mlir::CallOpInterface)))
    (define-op ret
      :summary "return from calltest.func"
      :traits (terminator))))
