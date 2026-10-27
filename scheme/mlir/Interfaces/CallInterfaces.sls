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
  (define mlir::CallableOpInterface::getCallableRegion
    %mlir::CallableOpInterface::getCallableRegion)
  (define mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
    %mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr)
  (define mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr
    %mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr)

  ) ;; end library (mlir Interfaces CallInterfaces)
