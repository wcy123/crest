#!r6rs
;; Mirrors mlir/Interfaces/InferTypeOpInterface.h
(library (mlir Interfaces InferTypeOpInterface ffi)
  (export %crest::InferTypeOpInterface::reportFailure
          %crest::InferTypeOpInterface::registerEntry
          %crest::InferTypeOpInterface::adapt
          %mlir::InferTypeOpInterface::inferReturnTypes<OperationState>
          %mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>)
  (import (chezscheme))

  (define %crest::InferTypeOpInterface::reportFailure
    (foreign-procedure "crest::InferTypeOpInterface::reportFailure" (string) void))

  (define %crest::InferTypeOpInterface::registerEntry
    (foreign-procedure "crest::InferTypeOpInterface::registerEntry" (string uptr) void))

  (define %crest::InferTypeOpInterface::adapt
    (foreign-procedure "crest::InferTypeOpInterface::adapt"
                       (scheme-object uptr uptr uptr uptr uptr uptr uptr uptr uptr uptr uptr)
                       unsigned-8))

  (define %mlir::InferTypeOpInterface::inferReturnTypes<OperationState>
    (foreign-procedure "mlir::InferTypeOpInterface::inferReturnTypes<OperationState>"
                       (uptr) scheme-object))

  (define %mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>
    (foreign-procedure "mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>"
                       (uptr) scheme-object))

  ) ;; end library (mlir Interfaces InferTypeOpInterface ffi)
