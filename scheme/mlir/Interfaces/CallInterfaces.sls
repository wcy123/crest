#!r6rs
;; Mirrors mlir/Interfaces/CallInterfaces.h
;;
;; The three interfaces are macros, the heads of the entries of the :interfaces clause of define-op
;; (see (mlir Interfaces InferTypeOpInterface)): an entry is the pair of the TypeID of the interface
;; (mlir::X::getInterfaceID) and the dispatcher of its clauses, which C++ asks for the entry point of
;; each method that Scheme implements while it registers the op (lib/Crest/Op.cpp).
(library (mlir Interfaces CallInterfaces)
  (export mlir::CallableOpInterface
          mlir::CallOpInterface
          mlir::ArgAndResultAttrsOpInterface
          mlir::CallableOpInterface::getInterfaceID
          mlir::CallOpInterface::getInterfaceID
          mlir::ArgAndResultAttrsOpInterface::getInterfaceID
          mlir::CallableOpInterface::getCallableRegion
          mlir::CallableOpInterface::getArgumentTypes
          mlir::CallableOpInterface::getResultTypes
          mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
          mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr
          mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr
          mlir::ArgAndResultAttrsOpInterface::setResAttrsAttr
          mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr
          mlir::ArgAndResultAttrsOpInterface::removeResAttrsAttr
          mlir::CallInterfaceCallable::get<SymbolRefAttr>
          mlir::CallInterfaceCallable::get<Value>
          mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr>
          mlir::CallInterfaceCallable::dyn_cast<Value>
          crest::OperandRange::get)
  (import (chezscheme)
          (crest callback)
          (for (crest interface) expand)
          (only (mlir IR Operation)
                mlir::Operation::getAttr
                mlir::Operation::setAttr!
                mlir::Operation::removeAttr)
          (mlir Interfaces CallInterfaces ffi))

  ;; MLIR has no default for the methods of CallableOpInterface (an op class gives them), and a dialect
  ;; keeps its signature where it wants, so an entry has all three clauses:
  ;;   (mlir::CallableOpInterface
  ;;     (getCallableRegion (op) body ...)   the Region that holds the body, or 0 for a declaration
  ;;     (getArgumentTypes (op) body ...)    a list of Types
  ;;     (getResultTypes (op) body ...))     a list of Types
  ;; Each becomes a foreign-callable, made once, whose address C++ puts in the slot of the Concept.
  ;; The slots that answer an ArrayRef get the types kept where the context owns them, so that the
  ;; ArrayRef outlives the call.
  (define (%%types->range clause)
    (lambda (op)
      (let ([types (clause op)])
        (cons (%crest::CallableOpInterface::keepTypes op types) (length types)))))

  (define-syntax mlir::CallableOpInterface
    (lambda (stx)
      (op-interface-expand
       stx 'mlir::CallableOpInterface #'(mlir::CallableOpInterface::getInterfaceID)
       #'((getCallableRegion (uptr) uptr #f #f ())
          (getArgumentTypes (uptr) range %%types->range #f ())
          (getResultTypes (uptr) range %%types->range #f ())))))

  ;; An entry of the :interfaces clause of define-op for CallOpInterface:
  ;;   (mlir::CallOpInterface
  ;;     (getCallableForCallee (op) body ...)       the callee: a CallInterfaceCallable
  ;;     (setCalleeFromCallable (op callee) body ...)
  ;;     (getArgOperands (op) body ...)             the arguments: (crest::OperandRange::get op start count)
  ;;     (getArgOperandsMutable :all-operands))     a C function that CREST ships: all the operands
  ;; MLIR has no default for these four (the op class gives them), so the op gives them. For
  ;; resolveCallableInTable and resolveCallable it has one, which looks the callee up as a symbol, and
  ;; an op that does not give them gets the same: a C function that CREST ships.
  ;; A CallInterfaceCallable is a SymbolRefAttr or a Value, as a number: make one with
  ;; mlir::CallInterfaceCallable::get<SymbolRefAttr> or get<Value>, and take it apart with dyn_cast<>,
  ;; which answers 0 for the other kind.
  (define-syntax mlir::CallOpInterface
    (lambda (stx)
      (op-interface-expand
       stx 'mlir::CallOpInterface #'(mlir::CallOpInterface::getInterfaceID)
       #'((getCallableForCallee (uptr) object #f #f ())
          (setCalleeFromCallable (uptr uptr) void #f #f ())
          (getArgOperands (uptr) range #f #f ())
          (getArgOperandsMutable (uptr) uptr #f #f
                                 ((:all-operands cpp (%crest::CallOpInterface::getArgOperandsMutable))))
          (resolveCallableInTable (uptr uptr) uptr #f
                                  (cpp (%crest::CallOpInterface::resolveCallableInTable)) ())
          (resolveCallable (uptr) uptr #f (cpp (%crest::CallOpInterface::resolveCallable)) ())))))

  ;; The standard clauses of ArgAndResultAttrsOpInterface keep the attributes in the op's
  ;; "arg_attrs" and "res_attrs" attributes, as an ODS op with those attributes does. A null
  ;; attribute is no attribute.
  (define (%%attribute-getter name)
    (lambda (op) (or (mlir::Operation::getAttr op name) 0)))

  (define (%%attribute-setter name)
    (lambda (op attrs)
      (if (zero? attrs)
          (mlir::Operation::removeAttr op name)
          (mlir::Operation::setAttr! op name attrs))))

  (define (%%attribute-remover name)
    (lambda (op) (or (mlir::Operation::removeAttr op name) 0)))

  ;; An entry of the :interfaces clause of define-op for ArgAndResultAttrsOpInterface, which
  ;; CallableOpInterface, CallOpInterface and FunctionOpInterface extend, so an op that has one of
  ;; them declares it too. MLIR has no default for its six methods, so the op gives them as clauses
  ;; (getArgAttrsAttr, getResAttrsAttr, setArgAttrsAttr, setResAttrsAttr, removeArgAttrsAttr,
  ;; removeResAttrsAttr), or writes
  ;;   (mlir::ArgAndResultAttrsOpInterface :standard)
  ;; for the clauses that keep "arg_attrs" and "res_attrs" attributes.
  (define-syntax mlir::ArgAndResultAttrsOpInterface
    (lambda (stx)
      (op-interface-expand
       stx 'mlir::ArgAndResultAttrsOpInterface #'(mlir::ArgAndResultAttrsOpInterface::getInterfaceID)
       #'((getArgAttrsAttr (uptr) object #f #f
                           ((:standard scheme (%%attribute-getter "arg_attrs"))))
          (getResAttrsAttr (uptr) object #f #f
                           ((:standard scheme (%%attribute-getter "res_attrs"))))
          (setArgAttrsAttr (uptr uptr) void #f #f
                           ((:standard scheme (%%attribute-setter "arg_attrs"))))
          (setResAttrsAttr (uptr uptr) void #f #f
                           ((:standard scheme (%%attribute-setter "res_attrs"))))
          (removeArgAttrsAttr (uptr) object #f #f
                              ((:standard scheme (%%attribute-remover "arg_attrs"))))
          (removeResAttrsAttr (uptr) object #f #f
                              ((:standard scheme (%%attribute-remover "res_attrs"))))))))

  (define mlir::CallableOpInterface::getInterfaceID
    %mlir::CallableOpInterface::getInterfaceID)

  (define mlir::CallOpInterface::getInterfaceID
    %mlir::CallOpInterface::getInterfaceID)

  (define mlir::ArgAndResultAttrsOpInterface::getInterfaceID
    %mlir::ArgAndResultAttrsOpInterface::getInterfaceID)

  (define (mlir::CallableOpInterface::getCallableRegion op)
    (%mlir::CallableOpInterface::getCallableRegion op))

  (define (mlir::CallableOpInterface::getArgumentTypes op)
    (%mlir::CallableOpInterface::getArgumentTypes op))

  (define (mlir::CallableOpInterface::getResultTypes op)
    (%mlir::CallableOpInterface::getResultTypes op))

  (define (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr op))

  (define (mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr op))

  (define (mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr op attrs)
    (%mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr op attrs))

  (define (mlir::ArgAndResultAttrsOpInterface::setResAttrsAttr op attrs)
    (%mlir::ArgAndResultAttrsOpInterface::setResAttrsAttr op attrs))

  (define (mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr op))

  (define (mlir::ArgAndResultAttrsOpInterface::removeResAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::removeResAttrsAttr op))

  (define mlir::CallInterfaceCallable::get<SymbolRefAttr>
    %mlir::CallInterfaceCallable::get<SymbolRefAttr>)

  (define mlir::CallInterfaceCallable::get<Value>
    %mlir::CallInterfaceCallable::get<Value>)

  ;; The SymbolRefAttr of a callee that is one, or #f for a Value.
  (define (mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr> callable)
    (let ([attr (%mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr> callable)])
      (if (zero? attr) #f attr)))

  ;; The Value of a callee that is one, or #f for a SymbolRefAttr.
  (define (mlir::CallInterfaceCallable::dyn_cast<Value> callable)
    (let ([value (%mlir::CallInterfaceCallable::dyn_cast<Value> callable)])
      (if (zero? value) #f value)))

  ;; The operands of the op from `start`, `count` of them, as the answer of getArgOperands.
  (define (crest::OperandRange::get op start count)
    (%crest::OperandRange::get op start count))

  ) ;; end library (mlir Interfaces CallInterfaces)
