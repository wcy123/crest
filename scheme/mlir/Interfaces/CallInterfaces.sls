#!r6rs
;; Mirrors mlir/Interfaces/CallInterfaces.h
;;
;; The three interfaces are macros, the heads of the entries of the :interfaces clause of define-op
;; (see (mlir Interfaces InferTypeOpInterface)): an entry is the pair of the TypeID of the interface
;; (mlir::X::getInterfaceID) and the dispatcher of its clauses, which C++ asks for the entry point of
;; each method that Scheme implements while it registers the op (lib/Crest/Op.cpp).
(library (mlir Interfaces CallInterfaces)
  (export mlir::CallableOpInterface
          mlir::CallOpInterface
          mlir::ArgAndResultAttrsOpInterface
          mlir::CallableOpInterface::getInterfaceID
          mlir::CallOpInterface::getInterfaceID
          mlir::ArgAndResultAttrsOpInterface::getInterfaceID
          mlir::CallableOpInterface::getCallableRegion
          mlir::CallableOpInterface::getArgumentTypes
          mlir::CallableOpInterface::getResultTypes
          mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
          mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr)
  (import (chezscheme)
          (crest callback)
          (for (crest interface) expand)
          (mlir Interfaces CallInterfaces ffi))

  ;; MLIR has no default for the methods of CallableOpInterface (an op class gives them), and a dialect
  ;; keeps its signature where it wants, so an entry has all three clauses:
  ;;   (mlir::CallableOpInterface
  ;;     (getCallableRegion (op) body ...)   the Region that holds the body, or 0 for a declaration
  ;;     (getArgumentTypes (op) body ...)    a list of Types
  ;;     (getResultTypes (op) body ...))     a list of Types
  ;; Each becomes a foreign-callable, made once, whose address C++ puts in the slot of the Concept.
  ;; The slots that answer an ArrayRef get the types kept where the context owns them, so that the
  ;; ArrayRef outlives the call.
  (define (%%types->range clause)
    (lambda (op)
      (let ([types (clause op)])
        (cons (%crest::CallableOpInterface::keepTypes op types) (length types)))))

  (define-syntax mlir::CallableOpInterface
    (lambda (stx)
      (op-interface-expand
       stx 'mlir::CallableOpInterface #'(mlir::CallableOpInterface::getInterfaceID)
       #'((getCallableRegion (uptr) uptr #f #f ())
          (getArgumentTypes (uptr) range %%types->range #f ())
          (getResultTypes (uptr) range %%types->range #f ())))))

  ;; The callee is the callee attribute and the arguments are the operands: no method for Scheme.
  (define-syntax mlir::CallOpInterface
    (lambda (stx)
      (syntax-case stx ()
        [(_) #'(cons (mlir::CallOpInterface::getInterfaceID) (crest-callback-entry-dispatcher '()))]
        [(_ clause ...)
         (syntax-violation ':interfaces
                           "mlir::CallOpInterface takes no method clauses: the callee is the callee attribute and the arguments are the operands"
                           stx)])))

  (define-syntax mlir::ArgAndResultAttrsOpInterface
    (lambda (stx)
      (syntax-case stx ()
        [(_) #'(cons (mlir::ArgAndResultAttrsOpInterface::getInterfaceID)
                     (crest-callback-entry-dispatcher '()))]
        [(_ clause ...)
         (syntax-violation ':interfaces
                           "mlir::ArgAndResultAttrsOpInterface takes no method clauses"
                           stx)])))

  (define mlir::CallableOpInterface::getInterfaceID
    %mlir::CallableOpInterface::getInterfaceID)

  (define mlir::CallOpInterface::getInterfaceID
    %mlir::CallOpInterface::getInterfaceID)

  (define mlir::ArgAndResultAttrsOpInterface::getInterfaceID
    %mlir::ArgAndResultAttrsOpInterface::getInterfaceID)

  (define (mlir::CallableOpInterface::getCallableRegion op)
    (%mlir::CallableOpInterface::getCallableRegion op))

  (define (mlir::CallableOpInterface::getArgumentTypes op)
    (%mlir::CallableOpInterface::getArgumentTypes op))

  (define (mlir::CallableOpInterface::getResultTypes op)
    (%mlir::CallableOpInterface::getResultTypes op))

  (define (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr op))

  (define (mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr op))

  ) ;; end library (mlir Interfaces CallInterfaces)
