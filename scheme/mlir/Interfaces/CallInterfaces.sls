#!r6rs
;; Mirrors mlir/Interfaces/CallInterfaces.h
;;
;; The three interfaces are macros, the heads of the entries of the :interface2 clause of define-op
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
          mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
          mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr)
  (import (chezscheme)
          (crest callback)
          (mlir Interfaces CallInterfaces ffi))

  ;; `dispatcher` is (lambda (method) ...): a method name answers its clause or #f. Only
  ;; getCallableRegion is a method that Scheme can implement: its foreign-callable gets the op and
  ;; answers the Region; without the clause the op's callable region is its first region.
  ;;   (mlir::CallableOpInterface (getCallableRegion (op) body ...))
  (define (%%callable-dispatcher dispatcher)
    (let ([get-region (dispatcher 'getCallableRegion)])
      (crest-callback-entry-dispatcher
       (list (cons 'getCallableRegion
                   (if get-region
                       (crest-callback-entry-point (uptr) uptr get-region)
                       0))))))

  (define-syntax mlir::CallableOpInterface
    (syntax-rules ()
      [(_ (method (formal ...) body ...) ...)
       (cons (mlir::CallableOpInterface::getInterfaceID)
             (%%callable-dispatcher
              (lambda (name)
                (case name
                  [(method) (lambda (formal ...) body ...)] ...
                  [else #f]))))]))

  ;; The callee is the callee attribute and the arguments are the operands: no method for Scheme.
  (define-syntax mlir::CallOpInterface
    (lambda (stx)
      (syntax-case stx ()
        [(_) #'(cons (mlir::CallOpInterface::getInterfaceID) (crest-callback-entry-dispatcher '()))]
        [(_ clause ...)
         (syntax-violation ':interface2
                           "mlir::CallOpInterface takes no method clauses: the callee is the callee attribute and the arguments are the operands"
                           stx)])))

  (define-syntax mlir::ArgAndResultAttrsOpInterface
    (lambda (stx)
      (syntax-case stx ()
        [(_) #'(cons (mlir::ArgAndResultAttrsOpInterface::getInterfaceID)
                     (crest-callback-entry-dispatcher '()))]
        [(_ clause ...)
         (syntax-violation ':interface2
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

  (define (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr op))

  (define (mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr op)
    (%mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr op))

  ) ;; end library (mlir Interfaces CallInterfaces)
