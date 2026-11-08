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

  ;; The C++ method is called with (context location operands attributes properties regions result)
  ;; as the platform ABI passes them: 10 or 11 machine words on System V x86-64 (the properties
  ;; are 16 bytes from LLVM 23), where the 16-byte classes take two words each, and 7 on Windows
  ;; x64, where they are passed by reference. The words go to the C++ adapter, which knows the
  ;; layout and calls `proc` with (context location operands attributes). The System V callable
  ;; takes 11 words; one more than the call passes (LLVM 22) is read and ignored.
  ;; An error in `proc` must not unwind through the C++ frames: it is reported and answers failure.
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

  (define (%%windows-entry-point proc)
    (let ([code (foreign-callable
                 (lambda (w0 w1 w2 w3 w4 w5 w6)
                   (%%infer proc w0 w1 w2 w3 w4 w5 w6 0 0 0 0))
                 (uptr uptr uptr uptr uptr uptr uptr)
                 unsigned-8)])
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
