#!r6rs
;; Mirrors mlir/Interfaces/InferTypeOpInterface.h
(library (mlir Interfaces InferTypeOpInterface ffi)
  (export %mlir::InferTypeOpInterface::getInterfaceID
          %crest::InferTypeOpInterface::decode
          %crest::InferTypeOpInterface::push
          %crest::InferTypeOpInterface::decodeCompatible
          %mlir::InferTypeOpInterface::inferReturnTypes<OperationState>
          %mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>)
  (import (chezscheme)
          (crest support foreign))

  ;; () → uptr — the TypeID of mlir::InferTypeOpInterface, as the address that TypeID wraps.
  (define %mlir::InferTypeOpInterface::getInterfaceID
    (crest-foreign-procedure "mlir::InferTypeOpInterface::getInterfaceID" () uptr))

  ;; (w0 ... w10) -> (context location operands attributes return-types sink): the arguments of MLIR's call
  ;; as Scheme data, and the place for the answer.
  (define %crest::InferTypeOpInterface::decode
    (crest-foreign-procedure "crest::InferTypeOpInterface::decode"
                             (uptr uptr uptr uptr uptr uptr uptr uptr uptr uptr uptr)
                             scheme-object))

  ;; (sink types refine) -> void: the answer of the clause, a list of Types, into the place for it.
  (define %crest::InferTypeOpInterface::push
    (crest-foreign-procedure "crest::InferTypeOpInterface::push" (uptr scheme-object int) void))

  ;; (w0 w1 w2 w3) -> (lhs rhs): the two lists of Types of isCompatibleReturnTypes.
  (define %crest::InferTypeOpInterface::decodeCompatible
    (crest-foreign-procedure "crest::InferTypeOpInterface::decodeCompatible" (uptr uptr uptr uptr)
                             scheme-object))

  (define %mlir::InferTypeOpInterface::inferReturnTypes<OperationState>
    (crest-foreign-procedure "mlir::InferTypeOpInterface::inferReturnTypes<OperationState>"
                             (uptr) scheme-object))

  (define %mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>
    (crest-foreign-procedure "mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>"
                             (uptr) scheme-object))

  ) ;; end library (mlir Interfaces InferTypeOpInterface ffi)
