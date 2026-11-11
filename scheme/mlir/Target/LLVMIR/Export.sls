#!r6rs
;; Mirrors mlir/Target/LLVMIR/Export.h
(library (mlir Target LLVMIR Export)
  (export mlir::translateModuleToLLVMIR)
  (import (rnrs)
          (only (chezscheme) foreign-ref foreign-free)
          (for (rime loop) expand)
          (mlir Target LLVMIR Export ffi))

  ;; The text at address as a string; the buffer is freed even if the copy raises an error.
  (define (%%take-text address)
    (dynamic-wind
        (lambda () #f)
        (lambda ()
          (let* ([size (let scan ([i 0])
                         (if (zero? (foreign-ref 'unsigned-8 address i)) i (scan (+ i 1))))]
                 [bytes (make-bytevector size)])
            (loop :for i :from 0 :below size
                  :do (bytevector-u8-set! bytes i (foreign-ref 'unsigned-8 address i)))
            (utf8->string bytes)))
        (lambda () (foreign-free address))))

  ;; (translateModuleToLLVMIR module) is the module translated to LLVM IR text.
  ;; (translateModuleToLLVMIR module opt-level) also sets the target triple and data layout of the
  ;; host and runs LLVM's optimizing pipeline at opt-level 0 to 3, as the C++ Toy tutorial does.
  (define mlir::translateModuleToLLVMIR
    (case-lambda
     [(module)           (%%take-text (%mlir::translateModuleToLLVMIR module))]
     [(module opt-level) (%%take-text (%mlir::translateModuleToLLVMIR<int> module opt-level))])))
