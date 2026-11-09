#!r6rs
;; Mirrors mlir/Interfaces/CallInterfaces.h
(library (mlir Interfaces CallInterfaces)
  (export mlir::CallableOpInterface
          mlir::CallOpInterface
          mlir::ArgAndResultAttrsOpInterface
          mlir::CallableOpInterface::getCallableRegion
          mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
          mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr)
  (import (chezscheme)
          (crest callback)
          (mlir Interfaces CallInterfaces ffi))

  ;; dispatcher: made by define-op for the op's :interfaces entry; 'operation_name answers the
  ;; op's name and a method name the clause or #f. Only getCallableRegion is a method that Scheme
  ;; can implement: its foreign-callable gets the op and answers the Region; without the clause the
  ;; op's callable region is its first region.
  (define (mlir::CallableOpInterface dispatcher)
    (let ([get-region (dispatcher 'getCallableRegion)])
      (%mlir::CallableOpInterface
       (dispatcher 'operation_name)
       (if get-region
           (crest-callback-entry-point (uptr) uptr get-region)
           0))))

  (define (mlir::CallOpInterface dispatcher)
    (%mlir::CallOpInterface (dispatcher 'operation_name)))

  (define (mlir::ArgAndResultAttrsOpInterface dispatcher)
    (%mlir::ArgAndResultAttrsOpInterface (dispatcher 'operation_name)))

  (define (mlir::CallableOpInterface::getCallableRegion op)
    (%mlir::CallableOpInterface::getCallableRegion op))

  (define (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr op))

  (define (mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr op))

  ) ;; end library (mlir Interfaces CallInterfaces)
