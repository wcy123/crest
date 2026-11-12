;; scheme-mlir driver: fails a partial conversion 1500 times with a pattern that makes a block and 1500 times
;; with one that does not, and prints "conversion-block-leak: ok" when the C++ heap grew by the same amount.
;; Linux only (mallinfo of glibc).
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef)
        (mlir Dialect Func IR FuncOps)
        (passes blocks))

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

(define runs 1500)

;; The growth of the C++ heap over `runs` conversions that fail, each on a module of its own.
(define (growth convert)
  (define (once)
    (with-DialectRegistry reg ()
      (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
      (with-MLIRContext ctx (reg)
        (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
        (mlir::MLIRContext::getOrLoadDialect ctx "func")
        (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx path)
          (when (convert module) (error 'conversion-block-leak "the conversion should fail"))))))
  (do ([i 0 (+ i 1)]) ((= i 30)) (once))
  (let ([before (bytes-in-use)])
    (do ([i 0 (+ i 1)]) ((= i runs)) (once))
    (- (bytes-in-use) before)))

(let* ([without (growth convert-without-block)]
       [with (growth convert-with-block)]
       [extra (- with without)])
  (display "conversion-block-leak: ")
  (display (if (< extra (* runs 30)) "ok" (list "leaked" extra "more with a block")))
  (newline))
