;; scheme-mlir driver: parses the input file 3000 times, each time in a context of its own with the
;; af dialect of test/dsl/assembly-format, and prints "assembly-format-leak: ok", or "... (leaked
;; <bytes>)" when the C++ heap in use grew. Linux only (mallinfo of glibc).
(import (chezscheme)
        (only (crest dialect) load-scheme-dialect!)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef)
        (mlir Dialect Func IR FuncOps))

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

(define (parse-once)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "func")
      (load-scheme-dialect! ctx "af" "passes/af")
      (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx path)
        (when (zero? module) (error 'assembly-format-leak "the input did not parse" path))))))

(define runs 3000)

(do ([i 0 (+ i 1)]) ((= i 50)) (parse-once))
(let ([before (bytes-in-use)])
  (do ([i 0 (+ i 1)]) ((= i runs)) (parse-once))
  (let ([grown (- (bytes-in-use) before)])
    (display "assembly-format-leak: ")
    (display (if (< grown (* runs 100)) "ok" (list "leaked" grown)))
    (newline)))
