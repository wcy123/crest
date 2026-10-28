#!r6rs
;; Mirrors mlir/Interfaces/CallInterfaces.h
(library (mlir Interfaces CallInterfaces)
  (export mlir::CallableOpInterface
          mlir::ArgAndResultAttrsOpInterface
          mlir::CallableOpInterface::getCallableRegion
          mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
          mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr)
  (import (rnrs)
          (mlir Interfaces CallInterfaces ffi))

  (define mlir::CallableOpInterface %mlir::CallableOpInterface)
  (define mlir::ArgAndResultAttrsOpInterface %mlir::ArgAndResultAttrsOpInterface)

  (define (mlir::CallableOpInterface::getCallableRegion op)
    (%mlir::CallableOpInterface::getCallableRegion op))

  (define (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr op))

  (define (mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr op))

  ) ;; end library (mlir Interfaces CallInterfaces)
