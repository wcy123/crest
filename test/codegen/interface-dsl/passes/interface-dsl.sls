#!r6rs
;; Unit test for the :interfaces DSL.
;; Uses locally-defined foreign-procedures to bypass scheme binary cache issues.
(library (passes interface-dsl)
  (export run-pass)
  (import (chezscheme)
          (crest dialect)
          (crest dialect ffi)
          (mlir IR Operation)
          (mlir IR Region)
          (mlir IR Block)
          (mlir IR MLIRContext))

  ;; Local foreign-procedure bindings ensure fresh symbol lookup regardless of
  ;; the compiled scheme binary cache state.
  (define %local::FunctionOpInterface::getFunctionType
    (foreign-procedure "mlir::FunctionOpInterface::getFunctionType" (uptr) uptr))
  (define %local::FunctionOpInterface::verifyBody
    (foreign-procedure "mlir::FunctionOpInterface::verifyBody" (uptr) boolean))
  (define %local::FunctionOpInterface::verifyType
    (foreign-procedure "mlir::FunctionOpInterface::verifyType" (uptr) boolean))
  (define %local::CallableOpInterface::getCallableRegion
    (foreign-procedure "mlir::CallableOpInterface::getCallableRegion" (uptr) uptr))
  (define %local::SymbolOpInterface::getNameAttr
    (foreign-procedure "mlir::SymbolOpInterface::getNameAttr" (uptr) uptr))

  (define-dialect ifacetest
    (define-op func
      :interfaces ((mlir::FunctionOpInterface))))

  (define (run-pass module)
    (let ([ctx (mlir::Operation::getContext module)])
      (with-current-MLIRContext ctx
        (ifacetest:register! ctx)
        (%crest::register-interface! "mlir::FunctionOpInterface"
                                     %%ifacetest.func:mlir::FunctionOpInterface)
        (let* ([body-region (mlir::Operation::getRegion module 0)]
               [body-block  (mlir::Region::front body-region)]
               [func-op     (mlir::Block::front body-block)])
          ;; Dispatcher contract.
          (display "dispatcher-op-name: ")
          (display (%%ifacetest.func:mlir::FunctionOpInterface 'operation_name))
          (newline)
          (display "dispatcher-getFunctionType: ")
          (display (%%ifacetest.func:mlir::FunctionOpInterface 'getFunctionType))
          (newline)
          (display "dispatcher-verifyBody: ")
          (display (%%ifacetest.func:mlir::FunctionOpInterface 'verifyBody))
          (newline)
          ;; C++ method dispatch via locally-defined foreign-procedures.
          (display "getFunctionType: ")
          (display (not (zero? (%local::FunctionOpInterface::getFunctionType func-op))))
          (newline)
          (display "verifyBody: ")
          (display (if (%local::FunctionOpInterface::verifyBody func-op) #t #f))
          (newline)
          (display "verifyType: ")
          (display (if (%local::FunctionOpInterface::verifyType func-op) #t #f))
          (newline)
          (display "getCallableRegion: ")
          (display (if (zero? (%local::CallableOpInterface::getCallableRegion func-op))
                       'null 'non-null))
          (newline)
          (display "getNameAttr: ")
          (display (if (zero? (%local::SymbolOpInterface::getNameAttr func-op))
                       'null 'non-null))
          (newline))))
    module)
  )
