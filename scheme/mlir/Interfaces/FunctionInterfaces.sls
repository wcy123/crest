#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces)
  (export mlir::FunctionOpInterface
          mlir::FunctionOpInterface::getInterfaceID
          mlir::function_interface_impl::parseFunctionOp
          mlir::function_interface_impl::printFunctionOp
          mlir::FunctionOpInterface::getFunctionType
          mlir::FunctionOpInterface::setFunctionTypeAttr
          mlir::FunctionOpInterface::cloneTypeWith
          mlir::FunctionOpInterface::verifyBody
          mlir::FunctionOpInterface::verifyType)
  (import (chezscheme)
          (crest callback)
          (mlir Interfaces FunctionInterfaces ffi))

  ;; The foreign-callable of verifyBody or verifyType: 1 for #t, 0 for any other answer. An error
  ;; must not escape into the C++ code above us, so its text goes to C++, whose diagnostic shows
  ;; it, and the answer is 0.
  (define (%%verifier-entry-point proc)
    (crest-callback-entry-point
     (uptr) int
     (lambda (op)
       (guard (c [#t (%crest::FunctionOpInterface::reportFailure
                      (call-with-string-output-port
                       (lambda (port) (display-condition c port))))
                     0])
         (if (eq? (proc op) #t) 1 0)))))

  ;; `dispatcher` is (lambda (method) ...): a method name answers its clause or #f. Each clause
  ;; becomes a foreign-callable, made once, whose address C++ keeps (a method without a clause is 0
  ;; and keeps the default):
  ;;   getFunctionType (op) -> Type            setFunctionTypeAttr (op attr)
  ;;   cloneTypeWith (op inputs results) -> Type, the two ranges as lists of Types
  ;;   verifyBody (op) -> boolean              verifyType (op) -> boolean
  (define (%%function-dispatcher dispatcher)
    (let ([get-type (dispatcher 'getFunctionType)]
          [set-attr (dispatcher 'setFunctionTypeAttr)]
          [clone    (dispatcher 'cloneTypeWith)]
          [body     (dispatcher 'verifyBody)]
          [type     (dispatcher 'verifyType)])
      (crest-callback-entry-dispatcher
       (list
        (cons 'getFunctionType
              (if get-type (crest-callback-entry-point (uptr) uptr get-type) 0))
        (cons 'setFunctionTypeAttr
              (if set-attr (crest-callback-entry-point (uptr uptr) void set-attr) 0))
        (cons 'cloneTypeWith
              (if clone
                  (crest-callback-entry-point
                   (uptr uptr uptr uptr uptr) uptr
                   (lambda (op inputs input-count results result-count)
                     (clone op
                            (crest-callback-pointer-list inputs input-count)
                            (crest-callback-pointer-list results result-count))))
                  0))
        (cons 'verifyBody (if body (%%verifier-entry-point body) 0))
        (cons 'verifyType (if type (%%verifier-entry-point type) 0))))))

  ;; An entry of the :interfaces clause of define-op (see (mlir Interfaces InferTypeOpInterface)):
  ;;   (mlir::FunctionOpInterface
  ;;     (getFunctionType (op) body ...) (setFunctionTypeAttr (op attr) body ...) ...)
  ;; the pair of the TypeID of the interface and the dispatcher of its clauses. The interfaces it
  ;; extends (SymbolOpInterface, ArgAndResultAttrsOpInterface, CallableOpInterface) come with it.
  (define-syntax mlir::FunctionOpInterface
    (syntax-rules ()
      [(_ (method (formal ...) body ...) ...)
       (cons (mlir::FunctionOpInterface::getInterfaceID)
             (%%function-dispatcher
              (lambda (name)
                (case name
                  [(method) (lambda (formal ...) body ...)] ...
                  [else #f]))))]))

  (define mlir::FunctionOpInterface::getInterfaceID
    %mlir::FunctionOpInterface::getInterfaceID)

  (define mlir::FunctionOpInterface::getFunctionType
    %mlir::FunctionOpInterface::getFunctionType)

  ;; The function type of the op with these inputs and results (two lists of Types), as its
  ;; cloneTypeWith clause says, or the default (a FunctionType).
  (define mlir::FunctionOpInterface::cloneTypeWith
    %mlir::FunctionOpInterface::cloneTypeWith)

  (define mlir::FunctionOpInterface::setFunctionTypeAttr
    %mlir::FunctionOpInterface::setFunctionTypeAttr)

  (define mlir::FunctionOpInterface::verifyBody
    %mlir::FunctionOpInterface::verifyBody)

  (define mlir::FunctionOpInterface::verifyType
    %mlir::FunctionOpInterface::verifyType)

  (define mlir::function_interface_impl::parseFunctionOp
    %mlir::function_interface_impl::parseFunctionOp)

  (define mlir::function_interface_impl::printFunctionOp
    %mlir::function_interface_impl::printFunctionOp)

  ) ;; end library (mlir Interfaces FunctionInterfaces)
