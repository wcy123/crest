#!r6rs
;; Mirrors mlir/Interfaces/CallInterfaces.h
(library (mlir Interfaces CallInterfaces ffi)
  (export %mlir::CallableOpInterface
          %mlir::ArgAndResultAttrsOpInterface
          %mlir::CallableOpInterface::getCallableRegion
          %mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
          %mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr)
  (import (chezscheme))

  (define %mlir::CallableOpInterface
    (foreign-procedure "mlir::CallableOpInterface" (scheme-object) void))

  (define %mlir::ArgAndResultAttrsOpInterface
    (foreign-procedure "mlir::ArgAndResultAttrsOpInterface" (scheme-object) void))

  (define %mlir::CallableOpInterface::getCallableRegion
    (foreign-procedure "mlir::CallableOpInterface::getCallableRegion" (uptr) uptr))

  (define %mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
    (foreign-procedure "mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr" (uptr) uptr))

  (define %mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr
    (foreign-procedure "mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr" (uptr) uptr))

  ) ;; end library (mlir Interfaces CallInterfaces ffi)
