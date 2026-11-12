;; scheme-mlir driver: a binding fails many times on operations whose names are short (no heap) and long (heap),
;; and Region::push_back<Block> fails after a block could have been made; the C++ heap must not grow for any.
;; Prints "error-path-leak: ok" and "block-leak: ok". Linux only (mallinfo of glibc).
(import (only (mlir Support WalkResult) mlir::WalkResult::advance)
        (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR OwningOpRef)
        (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface::getFunctionType)
        (only (mlir IR Location) mlir::UnknownLoc::get)
        (only (mlir IR OperationSupport) with-OperationState mlir::OperationState::addRegion)
        (only (mlir IR Region) mlir::Region::push_back<Block>))

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

;; The operations of the module, in order.
(define (operations module)
  (let ([found '()])
    (mlir::Operation::walk module (lambda (op) (set! found (cons op found)) mlir::WalkResult::advance))
    (reverse found)))

(define runs 3000)

;; The growth of the C++ heap over `runs` calls of thunk, each of which raises an error.
(define (growth-of thunk)
  (define (once) (guard (c [#t #f]) (thunk)))
  (do ([i 0 (+ i 1)]) ((= i 100)) (once))
  (let ([before (bytes-in-use)])
    (do ([i 0 (+ i 1)]) ((= i runs)) (once))
    (- (bytes-in-use) before)))

(define (report name extra limit)
  (display name)
  (display ": ")
  (display (if (< extra limit) "ok" (list "leaked" extra "more")))
  (newline))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx path)
      (let* ([ops (filter (lambda (op) (not (string=? (mlir::Operation::getName op) "builtin.module")))
                          (operations module))]
             [short (growth-of (lambda () (mlir::FunctionOpInterface::getFunctionType (car ops))))]
             [long (growth-of (lambda () (mlir::FunctionOpInterface::getFunctionType (cadr ops))))])
        (report "error-path-leak" (max short long) (* runs 24)))
      ;; push_back<Block> makes a block and then asks for a location, which raises when no context is
      ;; current. The block must not be left behind: compare with the same error raised alone.
      (with-OperationState state ((mlir::UnknownLoc::get ctx) "test.x")
        (let* ([region (mlir::OperationState::addRegion state)]
               [alone (growth-of (lambda () (mlir::UnknownLoc::get)))]
               [with-block (growth-of (lambda () (mlir::Region::push_back<Block> region '())))])
          (report "block-leak" (max with-block alone) (* runs 24)))))))
