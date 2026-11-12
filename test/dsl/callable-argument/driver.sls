;; The raw functions that C++ keeps a callback in reject a procedure and accept the address of a C
;; function made by crest-make-static-c-callable.
(import (rnrs)
        (only (chezscheme) printf)
        (only (crest callback) crest-make-static-c-callable)
        (mlir IR MLIRContext)
        (mlir IR DialectRegistry)
        (mlir Transforms DialectConversion)
        (only (mlir IR PatternMatch) with-RewritePatternSet))

(define (message-of thunk)
  (guard (c [#t (let ([text (condition-message c)]) (substring text 0 (min 52 (string-length text))))])
    (thunk)
    "no error"))

(define (report name thunk)
  (printf "~a: ~a\n" name (message-of thunk)))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (with-TypeConverter tc
      (with-ConversionTarget target (ctx)
        (with-RewritePatternSet patterns (ctx)
          (report "conversion" (lambda () (type-converter-add-conversion tc (lambda (t) t))))
          (report "legality"
                  (lambda () (target-mark-unknown-ops-dynamically-legal target (lambda (op) #t))))
          (report "pattern"
                  (lambda () (add-rewrite-pattern patterns "test.a" (lambda (op rw) #t) 1)))
          (let ([address (crest-make-static-c-callable (uptr) uptr (lambda (t) t))])
            (type-converter-add-conversion tc address)
            (printf "static address accepted: yes\n")))))))
