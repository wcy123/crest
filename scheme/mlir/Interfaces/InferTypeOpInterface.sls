#!r6rs
;; Mirrors mlir/Interfaces/InferTypeOpInterface.h
;;
;; mlir::InferTypeOpInterface is a macro, not an FFI binding: the head of an entry of the :interfaces
;; clause of define-op, which gives the op the methods of the interface that its clauses write.
;; MLIR calls inferReturnTypes through a plain function pointer that gets neither the op nor a
;; Concept, so the function has to be made per op: a foreign-callable, whose address C++ gets from
;; the entry (lib/Crest/InferType.cpp) and installs in the op's InterfaceMap when the op is registered.
(library (mlir Interfaces InferTypeOpInterface)
  (export mlir::InferTypeOpInterface
          mlir::InferTypeOpInterface::getInterfaceID
          mlir::InferTypeOpInterface::inferReturnTypes<OperationState>
          mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>)
  (import (chezscheme)
          (only (crest callback) crest-make-static-c-callable)
          (only (crest interface) crest-callback-entry-dispatcher)
          (mlir IR MLIRContext)
          (only (mlir IR Diagnostics) mlir::emitError)
          (only (mlir IR Types) mlir::Type::print)
          (mlir Interfaces InferTypeOpInterface ffi))

  ;; How MLIR's call reaches this function. MLIR calls it like any C function, and a C call is a
  ;; list of numbers, each 8 bytes (a pointer or an integer). This function gets them as w0, w1,
  ;; w2, ... in order. inferReturnTypes has seven inputs, but an input is not always one number:
  ;; a 16-byte C++ object, such as a ValueRange (a pointer and a count), does not fit in one.
  ;;
  ;;   Linux passes such an object as two numbers, its two halves (LLVM 22):
  ;;     w0 context | w1 w2 location | w3 w4 operands (pointer, count) | w5 attributes
  ;;     | w6 properties | w7 w8 regions | w9 where to put the result types
  ;;   In LLVM 23 the properties are 16 bytes too, so they take w6 w7, the regions w8 w9 and the
  ;;   result types go to w10.
  ;;
  ;;   Windows copies such an object to memory and passes one number, the address of the copy.
  ;;   (Windows also passes the address of a box for the answer before w0; see the comment above
  ;;   %%windows-entry-point, which takes it off as `result`.)
  ;;     w0 context | w1 address of location | w2 address of operands | w3 attributes
  ;;     | w4 properties | w5 address of regions | w6 where to put the result types
  ;;
  ;; The C++ function `decode` (lib/Bindings/Interfaces/InferTypeOpInterface.cpp) knows which number
  ;; is which. It rebuilds the C++ objects as Scheme data for `proc`, which is called with (context
  ;; location operands attributes). The Linux function always takes 11 numbers; with LLVM 22 the last
  ;; one is leftover memory and is ignored.
  ;;
  ;; MLIR calls these functions with its own prototype, so the callable made by crest-make-static-c-callable
  ;; (logical-result) guards the clause: an error is reported there. `decode` turns the words into Scheme data,
  ;; the clause is called here, in Scheme, and `push` gives its answer to MLIR. The context is set for the
  ;; clause (it builds types in it) and stays set, so that the guard can report in it.
  (define (%%infer proc refine w0 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10)
    (current-MLIRContext w0)
    (let* ([refine? (eqv? refine 1)]
           [arguments (%crest::InferTypeOpInterface::decode w0 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10)]
           [types (apply proc (list-head arguments (if refine? 5 4)))])
      (cond
       [types
        (%crest::InferTypeOpInterface::push (list-ref arguments 5) types refine)
        1]
       [else 0])))

  ;; Windows also wants the answer in a different place.
  ;;
  ;; MLIR's C++ code calls   LogicalResult r = inferReturnTypes(ctx, loc, ...);   and later tests r.
  ;;
  ;;   Linux: the function returns the answer, 1 (success) or 0 (failure), as its return value.
  ;;
  ;;   Windows: the caller rewrites the call into this:
  ;;       char box;                          // 1 byte on the caller's stack, say at 0x00A01000
  ;;       inferReturnTypes(&box, ctx, &loc, ...);
  ;;       ... later it reads `box` to get r.
  ;;     So the numbers this function receives start with the address of the box:
  ;;       number 0: 0x00A01000      the box           (the `result` parameter below)
  ;;       number 1: 0x1F4C0000      the context       (w0)
  ;;       number 2: 0x00A01040      the location copy (w1)
  ;;       ...
  ;;     The function must (1) write its answer, 1 or 0, into memory at 0x00A01000 and
  ;;     (2) return 0x00A01000, the address of the box, not the answer.
  ;;
  ;; The lists of w0, w1, ... above start after the box. Without the box in front, the first
  ;; number 0x00A01000 was taken to be the context and 0x1F4C0000 the address of the location, so
  ;; the function read memory at wrong addresses: that was the crash.
  ;;
  ;; Windows uses a box because LogicalResult is a class with a private field. It hands plain
  ;; values such as a bool back directly, but not a class like this one.
  ;; (crest-make-static-c-callable adds the box as the first argument and answers it, for logical-result.)
  ;; (%%infer-entry clause refine): the entry point of the callable of a clause of inferReturnTypes (refine 0)
  ;; or refineReturnTypes (refine 1), made from CLAUSE as it is written, so that an error is reported at its
  ;; position. The words of the call are 11 on Linux and 7 on Windows.
  (define-syntax %%infer-entry
    (syntax-rules ()
      [(_ clause refine)
       (case (machine-type)
         [(a6le ta6le a6osx ta6osx)
          (crest-make-static-c-callable
           (uptr uptr uptr uptr uptr uptr uptr uptr uptr uptr uptr) logical-result
           (let ([proc clause])
             (lambda (w0 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10)
               (%%infer proc refine w0 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10))))]
         [(a6nt ta6nt)
          (crest-make-static-c-callable
           (uptr uptr uptr uptr uptr uptr uptr) logical-result
           (let ([proc clause])
             (lambda (w0 w1 w2 w3 w4 w5 w6)
               (%%infer proc refine w0 w1 w2 w3 w4 w5 w6 0 0 0 0))))]
         [else (error 'mlir::InferTypeOpInterface
                      "the calling convention of this machine type is not supported"
                      (machine-type))])]))

  ;; The callable of an isCompatibleReturnTypes clause: MLIR calls it as
  ;; bool isCompatibleReturnTypes(TypeRange lhs, TypeRange rhs), and a TypeRange is 16 bytes, so it
  ;; comes as two numbers on Linux (w0 w1 | w2 w3) and as the address of a copy on Windows (w0 | w1),
  ;; like the ranges of inferReturnTypes above. `decodeCompatible` rebuilds the two ranges and `compatible` is called with
  ;; `compatible` with the lists of their Types.
  (define (%%compatible compatible w0 w1 w2 w3)
    (let ([types (%crest::InferTypeOpInterface::decodeCompatible w0 w1 w2 w3)])
      (if (compatible (car types) (cadr types)) 1 0)))

  (define-syntax %%compatible-entry
    (syntax-rules ()
      [(_ clause)
       (case (machine-type)
         [(a6le ta6le a6osx ta6osx)
          (crest-make-static-c-callable
           (uptr uptr uptr uptr) unsigned-8
           (let ([compatible clause])
             (lambda (w0 w1 w2 w3) (%%compatible compatible w0 w1 w2 w3))))]
         [(a6nt ta6nt)
          (crest-make-static-c-callable
           (uptr uptr) unsigned-8
           (let ([compatible clause])
             (lambda (w0 w1) (%%compatible compatible w0 w1 0 0))))]
         [else (error 'mlir::InferTypeOpInterface
                      "the calling convention of this machine type is not supported"
                      (machine-type))])]))

  ;; What MLIR does for an op that does not override the method (InferTypeOpInterface.td), written
  ;; here so that nothing hides in C++.
  ;;
  ;; isCompatibleReturnTypes: the types are the same.
  (define (%%default-compatible inferred actual)
    (equal? inferred actual))

  ;; refineReturnTypes: infer the result types with the clause of inferReturnTypes, and check that
  ;; they are compatible with the types the op has. An incompatible pair is an error at the location
  ;; (if there is one) and a failure; else the types stay as they are.
  (define (%%default-refine infer compatible)
    (lambda (context location operands attributes return-types)
      (let ([inferred (infer context location operands attributes)])
        (cond
         [(not inferred) #f]
         [(compatible inferred return-types) return-types]
         [else
          (when location
            (mlir::emitError
             location
             (string-append "op inferred type(s) " (%%types->string inferred)
                            " are incompatible with return type(s) of operation "
                            (%%types->string return-types))))
          #f]))))

  (define (%%types->string types)
    (let loop ([rest types] [text ""])
      (cond [(null? rest) text]
            [else (loop (cdr rest)
                        (string-append text (if (string=? text "") "" ", ")
                                       (mlir::Type::print (car rest))))])))

  ;; An entry of the :interfaces clause of define-op:
  ;;   (mlir::InferTypeOpInterface
  ;;     (inferReturnTypes (context location operands attributes) body ...)
  ;;     (refineReturnTypes (context location operands attributes return-types) body ...)
  ;;     (isCompatibleReturnTypes (inferred actual) body ...))
  ;; MLIR has no default for inferReturnTypes, so the op gives it; for the others it has, and an op
  ;; that does not give them gets MLIR's.
  ;;   inferReturnTypes         the result types, a list of Types, or #f when it cannot tell
  ;;   refineReturnTypes        the result types the op may have, given those it has (a list of
  ;;                            Types), or #f. By default: the result of inferReturnTypes has to be
  ;;                            compatible with the types the op has, or it is an error at the location
  ;;   isCompatibleReturnTypes  whether the result types of an op (a list of Types) fit what
  ;;                            inferReturnTypes answered (a list of Types). By default they must be
  ;;                            equal. An op whose inference is general and whose results get refined
  ;;                            later (a ranked tensor where the inference says tensor<*xf64>) says
  ;;                            what fits, as the ODS ops of C++ that override it do.
  ;; They are the methods that C++ code using the interface calls. Nothing checks the result types of
  ;; the op against them when the op is verified.
  ;; An entry is the pair of the TypeID of the interface and the dispatcher of C of its clauses. The
  ;; clauses are checked when the library compiles: inferReturnTypes is needed, a clause with another
  ;; name or two for one method are errors.
  (define-syntax mlir::InferTypeOpInterface
    (lambda (stx)
      (syntax-case stx ()
        [(_ (method (formal ...) body ...) ...)
         (let ([given (map syntax->datum #'(method ...))]
               [methods '(inferReturnTypes refineReturnTypes isCompatibleReturnTypes)])
           (for-each
            (lambda (name)
              (unless (memq name methods)
                (syntax-violation
                 ':interfaces
                 (string-append "mlir::InferTypeOpInterface has no method " (symbol->string name)
                                ": its methods are inferReturnTypes, refineReturnTypes and isCompatibleReturnTypes")
                 stx)))
            given)
           (for-each
            (lambda (name)
              (when (> (length (filter (lambda (other) (eq? other name)) given)) 1)
                (syntax-violation
                 ':interfaces
                 (string-append "mlir::InferTypeOpInterface has two clauses for " (symbol->string name))
                 stx)))
            given)
           (unless (memq 'inferReturnTypes given)
             (syntax-violation
              ':interfaces
              "mlir::InferTypeOpInterface needs a clause for inferReturnTypes: MLIR has no default, the op gives it"
              stx))
           ;; The callables are made here, once: the entry of :interfaces is evaluated when the library of
           ;; the dialect is loaded, and C++ gets the dispatcher with the TypeID of the interface, asks it
           ;; for the entries while it registers the op, and puts them in the slots of the Concept of the
           ;; op (lib/Crest/InferType.cpp). It does not keep the dispatcher. The clauses of
           ;; refineReturnTypes and isCompatibleReturnTypes that the op does not give are MLIR's.
           (let* ([clause-lambda
                   (lambda (name)
                     (let loop ([clauses (syntax->list #'((method (formal ...) body ...) ...))])
                       (and (pair? clauses)
                            (syntax-case (car clauses) ()
                              [(m (f ...) b ...)
                               (if (eq? (syntax->datum #'m) name)
                                   #'(lambda (f ...) b ...)
                                   (loop (cdr clauses)))]))))]
                  [infer (clause-lambda 'inferReturnTypes)]
                  [compatible (or (clause-lambda 'isCompatibleReturnTypes) #'%%default-compatible)]
                  [refine (or (clause-lambda 'refineReturnTypes)
                              #`(%%default-refine #,infer #,compatible))])
             #`(cons (mlir::InferTypeOpInterface::getInterfaceID)
                     (crest-callback-entry-dispatcher
                      (list (cons 'inferReturnTypes (%%infer-entry #,infer 0))
                            (cons 'refineReturnTypes (%%infer-entry #,refine 1))
                            (cons 'isCompatibleReturnTypes (%%compatible-entry #,compatible)))))))]
        [(_ clause ...)
         (syntax-violation ':interfaces
                           "mlir::InferTypeOpInterface clauses are written (method (formal ...) body ...)"
                           stx)])))

  (define mlir::InferTypeOpInterface::getInterfaceID
    %mlir::InferTypeOpInterface::getInterfaceID)

  (define mlir::InferTypeOpInterface::inferReturnTypes<OperationState>
    %mlir::InferTypeOpInterface::inferReturnTypes<OperationState>)

  (define mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>
    %mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>)

  ) ;; end library (mlir Interfaces InferTypeOpInterface)
