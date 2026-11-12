;; scheme-mlir driver: five kinds of callback raise an error. Prints the message that Scheme gets for each, then
;; "callback-errors: ok" when the C++ heap did not grow over 1500 rounds of all five. Linux only.
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef)
        (mlir Dialect Func IR FuncOps)
        (passes errors))

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

(define scenarios
  (list (cons "walk" walk-raises) (cons "legality" legality-raises) (cons "pattern" pattern-raises)
        (cons "conversion" conversion-raises) (cons "modify" modify-raises)))

(define (message-of thunk)
  (guard (c [#t (call-with-string-output-port (lambda (port) (display-condition c port)))])
    (thunk)
    "no error"))

;; One round: every scenario, each on a context and a module of its own, and the errors are caught.
(define (round-of report?)
  (for-each
   (lambda (scenario)
     (with-DialectRegistry reg ()
       (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
       (with-MLIRContext ctx (reg)
         (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
         (mlir::MLIRContext::getOrLoadDialect ctx "func")
         (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx path)
           (let ([message (message-of (lambda () ((cdr scenario) module)))])
             (when report?
               (display (car scenario)) (display ": ") (display message) (newline)))))))
   scenarios))

(round-of #t)
(do ([i 0 (+ i 1)]) ((= i 30)) (round-of #f))
(let ([before (bytes-in-use)])
  (do ([i 0 (+ i 1)]) ((= i 1500)) (round-of #f))
  (let ([grown (- (bytes-in-use) before)])
    (display "callback-errors: ")
    (display (if (< grown (* 1500 5 24)) "ok" (list "grew" grown "bytes")))
    (newline)))
