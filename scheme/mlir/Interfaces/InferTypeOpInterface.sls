#!r6rs
;; Mirrors mlir/Interfaces/InferTypeOpInterface.h
;;
;; mlir::InferTypeOpInterface is a Scheme procedure, not an FFI binding: it takes the dispatcher
;; that define-op makes for an :interfaces entry, and gives the op an inferReturnTypes of its own.
;; MLIR calls that method through a plain function pointer that gets neither the op nor a Concept,
;; so the function has to be made per op: a foreign-callable, whose address is registered with C++
;; (lib/Crest/InferType.cpp) and installed in the op's InterfaceMap when the op is registered.
(library (mlir Interfaces InferTypeOpInterface)
  (export mlir::InferTypeOpInterface
          mlir::InferTypeOpInterface::inferReturnTypes<OperationState>
          mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>)
  (import (chezscheme)
          (mlir IR MLIRContext)
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
  ;; The C++ function `adapt` (lib/Bindings/Interfaces/InferTypeOpInterface.cpp) knows which number
  ;; is which. It rebuilds the C++ objects and calls `proc` with (context location operands
  ;; attributes). The Linux function always takes 11 numbers; with LLVM 22 the last one is
  ;; leftover memory and is ignored.
  ;;
  ;; An error inside `proc` must not escape into the C++ code above us: its text goes to C++, whose
  ;; diagnostic shows it, and the answer is "failed" (0).
  (define (%%infer proc w0 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10)
    (guard (c [#t (%crest::InferTypeOpInterface::reportFailure
                   (call-with-string-output-port
                    (lambda (port) (display-condition c port))))
                  0])
      (with-current-MLIRContext w0
        (%crest::InferTypeOpInterface::adapt proc w0 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10))))

  (define (%%system-v-entry-point proc)
    (let ([code (foreign-callable
                 (lambda (w0 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10)
                   (%%infer proc w0 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10))
                 (uptr uptr uptr uptr uptr uptr uptr uptr uptr uptr uptr)
                 unsigned-8)])
      (lock-object code)
      (foreign-callable-entry-point code)))

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
  (define (%%windows-entry-point proc)
    (let ([code (foreign-callable
                 (lambda (result w0 w1 w2 w3 w4 w5 w6)
                   (foreign-set! 'unsigned-8 result 0 (%%infer proc w0 w1 w2 w3 w4 w5 w6 0 0 0 0))
                   result)
                 (uptr uptr uptr uptr uptr uptr uptr uptr)
                 uptr)])
      (lock-object code)
      (foreign-callable-entry-point code)))

  (define (%%entry-point proc)
    (case (machine-type)
      [(a6le ta6le a6osx ta6osx) (%%system-v-entry-point proc)]
      [(a6nt ta6nt) (%%windows-entry-point proc)]
      [else (error 'mlir::InferTypeOpInterface
                   "the calling convention of this machine type is not supported"
                   (machine-type))]))

  ;; dispatcher: (lambda (method) ...) made by define-op for the op's :interfaces entry;
  ;; 'operation_name answers the op's name and 'inferReturnTypes the method clause or #f.
  (define (mlir::InferTypeOpInterface dispatcher)
    (let ([op-name (dispatcher 'operation_name)]
          [method  (dispatcher 'inferReturnTypes)])
      (unless method
        (error 'mlir::InferTypeOpInterface
               "the interface needs an inferReturnTypes clause (context location operands attributes)"
               op-name))
      (%crest::InferTypeOpInterface::registerEntry op-name (%%entry-point method))))

  (define mlir::InferTypeOpInterface::inferReturnTypes<OperationState>
    %mlir::InferTypeOpInterface::inferReturnTypes<OperationState>)

  (define mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>
    %mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>)

  ) ;; end library (mlir Interfaces InferTypeOpInterface)
