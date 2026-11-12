;; A callable has the C prototype that C++ declares, result type included (plan 05). The result type is written at the
;; site: int, boolean, unsigned-8 and uptr answer what the procedure answered; an error of the procedure is a diagnostic
;; at the Scheme source of the callback, in (current-MLIRContext), and the callable answers the failure value of the
;; type (0, #f); void ends the process with the text; with no current context the process ends with the text.
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext)
        (mlir support with)
        (crest callback))

(define mode (car (command-line-arguments)))

(define (say . parts) (for-each display parts) (newline))

(define (call-int entry argument) ((foreign-procedure entry (int) int) argument))
(define (call-boolean entry argument) ((foreign-procedure entry (int) boolean) argument))
(define (call-unsigned-8 entry argument) ((foreign-procedure entry (int) unsigned-8) argument))
(define (call-uptr entry argument) ((foreign-procedure entry (int) uptr) argument))
(define (call-void entry argument) ((foreign-procedure entry (int) void) argument))

(define (run)
  (cond
   [(string=? mode "values")
    (with-c-callable (entry (int) int (lambda (x) (+ x 1))) (say "int: " (call-int entry 41)))
    (with-c-callable (entry (int) boolean (lambda (x) (> x 0))) (say "boolean: " (call-boolean entry 3)))
    (with-c-callable (entry (int) unsigned-8 (lambda (x) 1)) (say "unsigned-8: " (call-unsigned-8 entry 0)))
    (with-c-callable (entry (int) uptr (lambda (x) 4096)) (say "uptr: " (call-uptr entry 0)))
    (let ([entry (crest-make-static-c-callable (int) int (lambda (x) (* x 2)))])
      (say "static int: " (call-int entry 21)))]
   [(string=? mode "failure-values")
    ;; each error is a diagnostic, and the callable answers the failure value of its type
    (with-c-callable (entry (int) int (lambda (x) (error 'callback "int failed")))
      (say "int: " (call-int entry 1)))
    (with-c-callable (entry (int) boolean (lambda (x) (error 'callback "boolean failed")))
      (say "boolean: " (call-boolean entry 1)))
    (with-c-callable (entry (int) uptr (lambda (x) (error 'callback "uptr failed")))
      (say "uptr: " (call-uptr entry 1)))]
   [(or (string=? mode "void") (string=? mode "no-context"))
    (with-c-callable (entry (int) void (lambda (x) (error 'callback "void failed")))
      (call-void entry 1)
      (say "not reached"))]
   [else (error 'driver "unknown mode" mode)]))

(with* ((with-DialectRegistry registry ())
        (with-MLIRContext ctx (registry)))
  (if (string=? mode "no-context")
      (run)
      (with-current-MLIRContext ctx (run))))
