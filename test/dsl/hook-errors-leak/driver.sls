;; scheme-mlir driver: the verifier of a Scheme dialect raises an error. Each error is a diagnostic at the Scheme
;; source of the verifier, and the C++ heap must not grow over 1500 rounds. Prints "hook-errors-leak: ok".
;; Linux only. (An error of :initialize ends the process: test/dsl/dialect-initialize-error.)
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef)
        (mlir IR Operation)
        (crest dialect))

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

;; One round: a context with the dialect whose verifier raises, the module verified.
(define (round-of)
  (with-DialectRegistry reg ()
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
      (load-scheme-dialect! ctx "hkv" "passes/hk-verify")
      (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx path)
        (mlir::Operation::verify? module)))))

(do ([i 0 (+ i 1)]) ((= i 30)) (round-of))
(let ([before (bytes-in-use)])
  (do ([i 0 (+ i 1)]) ((= i 1500)) (round-of))
  (let ([grown (- (bytes-in-use) before)])
    (display "hook-errors-leak: ")
    (display (if (< grown (* 1500 24)) "ok" (list "grew" grown "bytes")))
    (newline)))
