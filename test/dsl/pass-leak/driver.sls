;; scheme-mlir driver: makes pass managers with passes many times and prints "pass-leak: ok", or
;; "pass-leak: leaked <bytes>" when the C++ heap in use grew. Linux only (mallinfo2 of glibc).
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext)
        (mlir Pass PassManager)
        (mlir Transforms Passes)
        (crest pass))

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

(define-pass (leak-pass op) #t)

(define (once ctx)
  (with-PassManager pm (ctx)
    (mlir::PassManager::addPass pm (mlir::createCanonicalizerPass))
    (mlir::PassManager::addPass pm (leak-pass))
    (let ([nested (mlir::PassManager::nest pm "func.func")])
      (mlir::OpPassManager::addPass nested (mlir::createCSEPass))
      (mlir::OpPassManager::addPass nested (leak-pass)))))

(define runs 5000)

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (do ([i 0 (+ i 1)]) ((= i 100)) (once ctx))
    (let ([before (bytes-in-use)])
      (do ([i 0 (+ i 1)]) ((= i runs)) (once ctx))
      (let ([grown (- (bytes-in-use) before)])
        (display "pass-leak: ")
        (display (if (< grown (* runs 4)) "ok" (list "leaked" grown)))
        (newline)))))
