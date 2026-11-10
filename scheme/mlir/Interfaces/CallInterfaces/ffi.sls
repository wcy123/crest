#!r6rs
;; Mirrors mlir/Interfaces/CallInterfaces.h
(library (mlir Interfaces CallInterfaces ffi)
  (export %mlir::CallableOpInterface::getInterfaceID
          %mlir::CallOpInterface::getInterfaceID
          %mlir::ArgAndResultAttrsOpInterface::getInterfaceID
          %mlir::CallableOpInterface::getCallableRegion
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

  (define %mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
    (foreign-procedure "mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr" (uptr) uptr))

  (define %mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr
    (foreign-procedure "mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr" (uptr) uptr))

  ) ;; end library (mlir Interfaces CallInterfaces ffi)
