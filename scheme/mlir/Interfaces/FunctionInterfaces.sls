#!r6rs
;; Mirrors mlir/Interfaces/FunctionInterfaces.h
(library (mlir Interfaces FunctionInterfaces)
  (export mlir::FunctionOpInterface
          mlir::function_interface_impl::parseFunctionOp
          mlir::function_interface_impl::printFunctionOp
          mlir::FunctionOpInterface::getFunctionType
          mlir::FunctionOpInterface::setFunctionTypeAttr
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

  ;; dispatcher: made by define-op for the op's :interfaces entry; 'operation_name answers the
  ;; op's name and a method name the clause or #f. Each clause becomes a foreign-callable whose
  ;; address C++ keeps (a method without a clause is 0 and keeps the default):
  ;;   getFunctionType (op) -> Type            setFunctionTypeAttr (op attr)
  ;;   cloneTypeWith (op inputs results) -> Type, the two ranges as lists of Types
  ;;   verifyBody (op) -> boolean              verifyType (op) -> boolean
  (define (mlir::FunctionOpInterface dispatcher)
    (let ([get-type (dispatcher 'getFunctionType)]
          [set-attr (dispatcher 'setFunctionTypeAttr)]
          [clone    (dispatcher 'cloneTypeWith)]
          [body     (dispatcher 'verifyBody)]
          [type     (dispatcher 'verifyType)])
      (%mlir::FunctionOpInterface
       (dispatcher 'operation_name)
       (if get-type (crest-callback-entry-point (uptr) uptr get-type) 0)
       (if set-attr (crest-callback-entry-point (uptr uptr) void set-attr) 0)
       (if clone
           (crest-callback-entry-point
            (uptr uptr uptr uptr uptr) uptr
            (lambda (op inputs input-count results result-count)
              (clone op
                     (crest-callback-pointer-list inputs input-count)
                     (crest-callback-pointer-list results result-count))))
           0)
       (if body (%%verifier-entry-point body) 0)
       (if type (%%verifier-entry-point type) 0))))

  (define mlir::FunctionOpInterface::getFunctionType
    %mlir::FunctionOpInterface::getFunctionType)

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
