;; scheme-mlir driver: translates the input module to LLVM IR text 2000 times (with and without an
;; optimization level) and prints "llvm-ir-text: ok" when the text is right and "llvm-ir-leak: ok", or
;; "... (leaked <bytes>)", when the C++ heap in use did not grow. Linux only (mallinfo of glibc).
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef)
        (mlir Dialect LLVMIR IR LLVMDialect)
        (mlir Target LLVMIR Export))

(load-shared-object "libc.so.6")

;; glibc 2.33 and later have mallinfo2 (fields of size_t); older glibc has mallinfo (fields of int).
(define-ftype mallinfo2-result
  (struct [arena size_t] [ordblks size_t] [smblks size_t] [hblks size_t] [hblkhd size_t]
          [usmblks size_t] [fsmblks size_t] [uordblks size_t] [fordblks size_t] [keepcost size_t]))
(define-ftype mallinfo-result
  (struct [arena int] [ordblks int] [smblks int] [hblks int] [hblkhd int]
          [usmblks int] [fsmblks int] [uordblks int] [fordblks int] [keepcost int]))

;; The bytes that malloc has given out and not got back.
(define bytes-in-use-now
  (if (foreign-entry? "mallinfo2")
      (let ([mallinfo2 (foreign-procedure "mallinfo2" () (& mallinfo2-result))])
        (lambda ()
          (let ([result (make-ftype-pointer mallinfo2-result
                                            (foreign-alloc (ftype-sizeof mallinfo2-result)))])
            (mallinfo2 result)
            (let ([used (ftype-ref mallinfo2-result (uordblks) result)])
              (foreign-free (ftype-pointer-address result))
              used))))
      (let ([mallinfo (foreign-procedure "mallinfo" () (& mallinfo-result))])
        (lambda ()
          (let ([result (make-ftype-pointer mallinfo-result
                                            (foreign-alloc (ftype-sizeof mallinfo-result)))])
            (mallinfo result)
            (let ([used (ftype-ref mallinfo-result (uordblks) result)])
              (foreign-free (ftype-pointer-address result))
              used))))))

(define (bytes-in-use)
  (collect 4 4)
  (bytes-in-use-now))

(define path (car (command-line-arguments)))

(define (contains? text part)
  (let ([n (string-length part)])
    (let loop ([i 0])
      (cond [(> (+ i n) (string-length text)) #f]
            [(string=? (substring text i (+ i n)) part) #t]
            [else (loop (+ i 1))]))))

(define runs 2000)

(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect> reg)
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::getOrLoadDialect ctx "llvm")
    (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx path)
      (let ([plain (mlir::translateModuleToLLVMIR module)]
            [optimized (mlir::translateModuleToLLVMIR module 2)])
        (display "llvm-ir-text: ")
        (display (if (and (contains? plain "define i32 @f") (contains? optimized "define")) "ok" "wrong"))
        (newline))
      (do ([i 0 (+ i 1)]) ((= i 50))
        (mlir::translateModuleToLLVMIR module)
        (mlir::translateModuleToLLVMIR module 2))
      (let ([before (bytes-in-use)])
        (do ([i 0 (+ i 1)]) ((= i runs))
          (mlir::translateModuleToLLVMIR module)
          (mlir::translateModuleToLLVMIR module 2))
        (let ([grown (- (bytes-in-use) before)])
          (display "llvm-ir-leak: ")
          (display (if (< grown (* runs 200)) "ok" (list "leaked" grown)))
          (newline))))))
