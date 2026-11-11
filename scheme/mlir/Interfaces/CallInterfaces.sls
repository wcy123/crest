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
          (mlir Interfaces CallInterfaces ffi))

  ;; llvm::ArrayRef<Type>: a pointer and a count. C++ returns it by value, and Chez makes a callable
  ;; that answers a struct follow the rules of the platform (two registers, or a pointer to the
  ;; place for the answer): the procedure gets that place as its first argument.
  (define-ftype %%ArrayRef (struct [data uptr] [size uptr]))

  ;; `dispatcher` is (lambda (method) ...): a method name answers its clause. MLIR has no default for
  ;; the methods of CallableOpInterface (an op class gives them), and a dialect keeps its signature
  ;; where it wants, so an entry has all three clauses:
  ;;   (mlir::CallableOpInterface
  ;;     (getCallableRegion (op) body ...)   the Region that holds the body, or 0 for a declaration
  ;;     (getArgumentTypes (op) body ...)    a list of Types
  ;;     (getResultTypes (op) body ...))     a list of Types
  ;; Each becomes a foreign-callable, made once, whose address C++ puts in the slot of the Concept,
  ;; so MLIR calls it with the Concept first and then the op (the Concept is ignored).
  (define (%%callable-dispatcher dispatcher)
    (let ([get-region (dispatcher 'getCallableRegion)]
          [get-arguments (dispatcher 'getArgumentTypes)]
          [get-results (dispatcher 'getResultTypes)])
      (define (types-entry-point get-types)
        (crest-callback-entry-point
         (uptr uptr) (& %%ArrayRef)
         (lambda (answer concept op)
           (let ([types (get-types op)])
             (ftype-set! %%ArrayRef (data) answer (%crest::CallableOpInterface::keepTypes op types))
             (ftype-set! %%ArrayRef (size) answer (length types))))))
      (crest-callback-entry-dispatcher
       (list (cons 'getCallableRegion
                   (crest-callback-entry-point (uptr uptr) uptr
                                               (lambda (concept op) (get-region op))))
             (cons 'getArgumentTypes (types-entry-point get-arguments))
             (cons 'getResultTypes (types-entry-point get-results))))))

  ;; The clauses are checked when the library compiles: all three, each once, and no other name.
  (define-syntax mlir::CallableOpInterface
    (lambda (stx)
      (syntax-case stx ()
        [(_ (method (formal ...) body ...) ...)
         (let ([given (map syntax->datum #'(method ...))]
               [required '(getCallableRegion getArgumentTypes getResultTypes)])
           (for-each
            (lambda (name)
              (unless (memq name required)
                (syntax-violation
                 ':interfaces
                 (string-append "mlir::CallableOpInterface has no method " (symbol->string name)
                                ": its methods are getCallableRegion, getArgumentTypes and getResultTypes")
                 stx)))
            given)
           (for-each
            (lambda (name)
              (when (> (length (filter (lambda (other) (eq? other name)) given)) 1)
                (syntax-violation
                 ':interfaces
                 (string-append "mlir::CallableOpInterface has two clauses for " (symbol->string name))
                 stx)))
            given)
           (for-each
            (lambda (name)
              (unless (memq name given)
                (syntax-violation
                 ':interfaces
                 (string-append "mlir::CallableOpInterface needs a clause for " (symbol->string name)
                                ": MLIR has no default, the op gives getCallableRegion, getArgumentTypes and getResultTypes")
                 stx)))
            required)
           #'(cons (mlir::CallableOpInterface::getInterfaceID)
                   (%%callable-dispatcher
                    (lambda (name)
                      (case name
                        [(method) (lambda (formal ...) body ...)] ...
                        [else #f])))))]
        [(_ clause ...)
         (syntax-violation ':interfaces
                           "mlir::CallableOpInterface clauses are written (method (op) body ...)"
                           stx)])))

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
