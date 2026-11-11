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
          %mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr)
  (import (chezscheme))

  ;; () -> uptr: the TypeID of the interface, as the address that the TypeID wraps.
  (define %mlir::CallableOpInterface::getInterfaceID
    (foreign-procedure "mlir::CallableOpInterface::getInterfaceID" () uptr))

  (define %mlir::CallOpInterface::getInterfaceID
    (foreign-procedure "mlir::CallOpInterface::getInterfaceID" () uptr))

  (define %mlir::ArgAndResultAttrsOpInterface::getInterfaceID
    (foreign-procedure "mlir::ArgAndResultAttrsOpInterface::getInterfaceID" () uptr))

  (define %mlir::CallableOpInterface::getCallableRegion
    (foreign-procedure "mlir::CallableOpInterface::getCallableRegion" (uptr) uptr))

  ;; (uptr op) -> list of Type
  (define %mlir::CallableOpInterface::getArgumentTypes
    (foreign-procedure "mlir::CallableOpInterface::getArgumentTypes" (uptr) scheme-object))

  (define %mlir::CallableOpInterface::getResultTypes
    (foreign-procedure "mlir::CallableOpInterface::getResultTypes" (uptr) scheme-object))

  ;; (uptr op, list types) -> uptr: keeps the types where the context of the op owns them and
  ;; answers the address of the first, for the ArrayRef that a callable of getArgumentTypes or
  ;; getResultTypes answers.
  (define %crest::CallableOpInterface::keepTypes
    (foreign-procedure "crest::CallableOpInterface::keepTypes" (uptr scheme-object) uptr))

  (define %mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
    (foreign-procedure "mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr" (uptr) uptr))

  (define %mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr
    (foreign-procedure "mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr" (uptr) uptr))

  ) ;; end library (mlir Interfaces CallInterfaces ffi)
