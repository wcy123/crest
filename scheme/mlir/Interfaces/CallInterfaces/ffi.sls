#!r6rs
;; Mirrors mlir/Interfaces/CallInterfaces.h
(library (mlir Interfaces CallInterfaces ffi)
  (export %mlir::CallableOpInterface::getInterfaceID
          %mlir::CallOpInterface::getInterfaceID
          %mlir::ArgAndResultAttrsOpInterface::getInterfaceID
          %mlir::CallableOpInterface::getCallableRegion
          %mlir::CallableOpInterface::getArgumentTypes
          %mlir::CallableOpInterface::getResultTypes
          %crest::CallableOpInterface::keepTypes
          %mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
          %mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr
          %mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr
          %mlir::ArgAndResultAttrsOpInterface::setResAttrsAttr
          %mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr
          %mlir::ArgAndResultAttrsOpInterface::removeResAttrsAttr
          %crest::CallOpInterface::getArgOperandsMutable
          %crest::CallOpInterface::resolveCallableInTable
          %crest::CallOpInterface::resolveCallable
          %mlir::CallInterfaceCallable::get<SymbolRefAttr>
          %mlir::CallInterfaceCallable::get<Value>
          %mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr>
          %mlir::CallInterfaceCallable::dyn_cast<Value>
          %crest::OperandRange::get)
  (import (chezscheme)
          (crest support foreign))

  ;; () -> uptr: the TypeID of the interface, as the address that the TypeID wraps.
  (define %mlir::CallableOpInterface::getInterfaceID
    (crest-foreign-procedure "mlir::CallableOpInterface::getInterfaceID" () uptr))

  (define %mlir::CallOpInterface::getInterfaceID
    (crest-foreign-procedure "mlir::CallOpInterface::getInterfaceID" () uptr))

  (define %mlir::ArgAndResultAttrsOpInterface::getInterfaceID
    (crest-foreign-procedure "mlir::ArgAndResultAttrsOpInterface::getInterfaceID" () uptr))

  (define %mlir::CallableOpInterface::getCallableRegion
    (crest-foreign-procedure "mlir::CallableOpInterface::getCallableRegion" (uptr) uptr))

  ;; (uptr op) -> list of Type
  (define %mlir::CallableOpInterface::getArgumentTypes
    (crest-foreign-procedure "mlir::CallableOpInterface::getArgumentTypes" (uptr) scheme-object))

  (define %mlir::CallableOpInterface::getResultTypes
    (crest-foreign-procedure "mlir::CallableOpInterface::getResultTypes" (uptr) scheme-object))

  ;; (uptr op, list types) -> uptr: keeps the types where the context of the op owns them and
  ;; answers the address of the first, for the ArrayRef that a callable of getArgumentTypes or
  ;; getResultTypes answers.
  (define %crest::CallableOpInterface::keepTypes
    (crest-foreign-procedure "crest::CallableOpInterface::keepTypes" (uptr scheme-object) uptr))

  (define %mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
    (crest-foreign-procedure "mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr" (uptr) uptr))

  (define %mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr
    (crest-foreign-procedure "mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr" (uptr) uptr))

  (define %mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr
    (crest-foreign-procedure "mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr" (uptr uptr) void))

  (define %mlir::ArgAndResultAttrsOpInterface::setResAttrsAttr
    (crest-foreign-procedure "mlir::ArgAndResultAttrsOpInterface::setResAttrsAttr" (uptr uptr) void))

  (define %mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr
    (crest-foreign-procedure "mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr" (uptr) uptr))

  (define %mlir::ArgAndResultAttrsOpInterface::removeResAttrsAttr
    (crest-foreign-procedure "mlir::ArgAndResultAttrsOpInterface::removeResAttrsAttr" (uptr) uptr))

  ;; () -> uptr: the address of a C function that CREST ships for a slot of CallOpInterface that
  ;; Scheme cannot write (see lib/Bindings/Interfaces/CallInterfaces.cpp).
  (define %crest::CallOpInterface::getArgOperandsMutable
    (crest-foreign-procedure "crest::CallOpInterface::getArgOperandsMutable" () uptr))

  (define %crest::CallOpInterface::resolveCallableInTable
    (crest-foreign-procedure "crest::CallOpInterface::resolveCallableInTable" () uptr))

  (define %crest::CallOpInterface::resolveCallable
    (crest-foreign-procedure "crest::CallOpInterface::resolveCallable" () uptr))

  ;; A CallInterfaceCallable (a PointerUnion of a SymbolRefAttr and a Value) as a number, and back.
  (define %mlir::CallInterfaceCallable::get<SymbolRefAttr>
    (crest-foreign-procedure "mlir::CallInterfaceCallable::get<SymbolRefAttr>" (uptr) uptr))

  (define %mlir::CallInterfaceCallable::get<Value>
    (crest-foreign-procedure "mlir::CallInterfaceCallable::get<Value>" (uptr) uptr))

  (define %mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr>
    (crest-foreign-procedure "mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr>" (uptr) uptr))

  (define %mlir::CallInterfaceCallable::dyn_cast<Value>
    (crest-foreign-procedure "mlir::CallInterfaceCallable::dyn_cast<Value>" (uptr) uptr))

  ;; (uptr op, unsigned start, unsigned count) -> (data . size): the operands of the op from start,
  ;; as the answer of getArgOperands.
  (define %crest::OperandRange::get
    (crest-foreign-procedure "crest::OperandRange::get" (uptr unsigned-32 unsigned-32) scheme-object))

  ) ;; end library (mlir Interfaces CallInterfaces ffi)
