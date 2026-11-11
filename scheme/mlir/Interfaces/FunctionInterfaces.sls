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
          (for (crest interface) expand)
          (only (mlir IR Operation)
                mlir::Operation::emitOpError
                mlir::Operation::getContext)
          (only (mlir IR Region) mlir::Region::front)
          (only (mlir IR Block) mlir::Block::getNumArguments mlir::Block::getArgument)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Types) mlir::Type::print)
          (only (mlir IR BuiltinTypes) mlir::FunctionType::get)
          (only (mlir Interfaces CallInterfaces)
                mlir::CallableOpInterface::getCallableRegion
                mlir::CallableOpInterface::getArgumentTypes)
          (mlir Interfaces FunctionInterfaces ffi))

  ;; What MLIR does for an op that does not override the method (FunctionInterfaces.td), written
  ;; here so that nothing hides in C++: an op that does not give the clause gets these.

  ;; cloneTypeWith: the function type of the op with these inputs and results.
  (define (%%default-clone-type-with op inputs results)
    (mlir::FunctionType::get (mlir::Operation::getContext op) inputs results))

  ;; verifyBody: a function that has a body has an entry block whose arguments are the inputs of
  ;; its type, in number and in types. A declaration (no region, or no block) has nothing to check.
  (define (%%default-verify-body op)
    (let* ([region (mlir::CallableOpInterface::getCallableRegion op)]
           [entry (if (zero? region) 0 (mlir::Region::front region))])
      (or (zero? entry)
          (let* ([inputs (mlir::CallableOpInterface::getArgumentTypes op)]
                 [count (length inputs)]
                 [index -1])
            (if (= (mlir::Block::getNumArguments entry) count)
                (for-all
                 (lambda (expected)
                   (set! index (+ index 1))
                   (let ([actual (mlir::Value::getType (mlir::Block::getArgument entry index))])
                     (or (= actual expected)
                         (begin
                           (mlir::Operation::emitOpError
                            op
                            (string-append "type of entry block argument #" (number->string index)
                                           "(" (mlir::Type::print actual)
                                           ") must match the type of the corresponding argument in function signature("
                                           (mlir::Type::print expected) ")"))
                           #f))))
                 inputs)
                (begin
                  (mlir::Operation::emitOpError
                   op
                   (string-append "entry block must have " (number->string count)
                                  " arguments to match function signature"))
                  #f))))))

  ;; verifyType: nothing to check beyond the type.
  (define (%%default-verify-type op) #t)

  ;; The procedure of a verifier clause: #t is success, and anything else or an error is a failure
  ;; with a diagnostic when it is an error, whose text is the condition. An error must not escape
  ;; into the C++ code above us.
  (define (%%verifier clause)
    (lambda (op)
      (guard (c [#t (mlir::Operation::emitOpError
                     op (call-with-string-output-port
                         (lambda (port) (display-condition c port))))
                    0])
        (if (eq? (clause op) #t) 1 0))))

  ;; An entry of the :interfaces clause of define-op:
  ;;   (mlir::FunctionOpInterface
  ;;     (getFunctionType (op) body ...)                  the Type
  ;;     (setFunctionTypeAttr (op attr) body ...)         attr is a TypeAttr
  ;;     (cloneTypeWith (op inputs results) body ...)     optional: a Type; the two ranges are lists
  ;;     (verifyBody (op) body ...)                       optional: #t for success
  ;;     (verifyType (op) body ...))                      optional: #t for success
  ;; the pair of the TypeID of the interface and the dispatcher of its clauses. MLIR has no default
  ;; for getFunctionType and setFunctionTypeAttr, so the op gives them; for the others it has, and an
  ;; op that does not give them gets MLIR's. SymbolOpInterface and ArgAndResultAttrsOpInterface,
  ;; which it extends, come with it. CallableOpInterface does not: the op declares it with its three
  ;; clauses too (an op that does not cannot be registered).
  (define-syntax mlir::FunctionOpInterface
    (lambda (stx)
      (op-interface-expand
       stx 'mlir::FunctionOpInterface #'(mlir::FunctionOpInterface::getInterfaceID)
       #'((getFunctionType (uptr) object #f #f ())
          (setFunctionTypeAttr (uptr object) void #f #f ())
          (cloneTypeWith (uptr type-range type-range) object #f %%default-clone-type-with ())
          (verifyBody (uptr) logical-result %%verifier %%default-verify-body ())
          (verifyType (uptr) logical-result %%verifier %%default-verify-type ())))))

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
