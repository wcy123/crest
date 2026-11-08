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
          mlir::InferTypeOpInterface::inferReturnTypes<OperationState>)
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
  ;;   Windows copies such an object to memory and passes one number, the address of the copy:
  ;;     w0 context | w1 address of location | w2 address of operands | w3 attributes
  ;;     | w4 properties | w5 address of regions | w6 where to put the result types
  ;;
  ;; The C++ function `adapt` (lib/Bindings/Interfaces/InferTypeOpInterface.cpp) knows which number
  ;; is which. It rebuilds the C++ objects and calls `proc` with (context location operands
  ;; attributes). The Linux function always takes 11 numbers; with LLVM 22 the last one is
  ;; leftover memory and is ignored.
  ;;
  ;; An error inside `proc` must not escape into the C++ code above us, so it is printed here and
  ;; the answer is "failed" (0).
  (define (%%infer proc w0 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10)
    (guard (c [#t (let ([port (current-error-port)])
                    (display-condition c port)
                    (newline port)
                    0)])
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

  ;; Windows also wants the answer in a different place. The C++ function returns a LogicalResult,
  ;; which is a yes or a no. On Linux that is just the returned byte. On Windows the caller sets
  ;; aside a small box in memory and passes the box's address as an extra number BEFORE all the
  ;; others. This function has to put its yes (1) or no (0) into the box and return the box's
  ;; address. (Windows does this because LogicalResult is a class with a private field, not a
  ;; plain value.)
  ;;
  ;;   (lambda (result w0 w1 ...) ...)
  ;;   result is the address of the box, w0 the context, w1 the address of the location, ...
  ;;
  ;; Without the extra first number, w0 would be taken to be the box and every other number would
  ;; be read one place too early: that was the crash.
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

  ) ;; end library (mlir Interfaces InferTypeOpInterface)
