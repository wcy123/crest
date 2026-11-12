#!r6rs
;; Mirrors mlir/Interfaces/InferTypeOpInterface.h
(library (mlir Interfaces InferTypeOpInterface ffi)
  (export %crest::InferTypeOpInterface::reportFailure
          %mlir::InferTypeOpInterface::getInterfaceID
          %crest::InferTypeOpInterface::adapt
          %crest::InferTypeOpInterface::adaptCompatible
          %mlir::InferTypeOpInterface::inferReturnTypes<OperationState>
          %mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>)
  (import (chezscheme)
          (mlir support foreign))

  (define %crest::InferTypeOpInterface::reportFailure
    (crest-foreign-procedure "crest::InferTypeOpInterface::reportFailure" (string) void))

  ;; () → uptr — the TypeID of mlir::InferTypeOpInterface, as the address that TypeID wraps.
  (define %mlir::InferTypeOpInterface::getInterfaceID
    (crest-foreign-procedure "mlir::InferTypeOpInterface::getInterfaceID" () uptr))

  (define %crest::InferTypeOpInterface::adapt
    (crest-foreign-procedure "crest::InferTypeOpInterface::adapt"
                             (scheme-object uptr uptr uptr uptr uptr uptr uptr uptr uptr uptr uptr int)
                             unsigned-8))

  (define %crest::InferTypeOpInterface::adaptCompatible
    (crest-foreign-procedure "crest::InferTypeOpInterface::adaptCompatible"
                             (scheme-object uptr uptr uptr uptr)
                             unsigned-8))

  (define %mlir::InferTypeOpInterface::inferReturnTypes<OperationState>
    (crest-foreign-procedure "mlir::InferTypeOpInterface::inferReturnTypes<OperationState>"
                             (uptr) scheme-object))

  (define %mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>
    (crest-foreign-procedure "mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>"
                             (uptr) scheme-object))

  ) ;; end library (mlir Interfaces InferTypeOpInterface ffi)
