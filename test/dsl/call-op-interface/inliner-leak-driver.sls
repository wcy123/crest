;; scheme-mlir driver: loads the calltest dialect (passes/call-dialect), which has an inliner
;; interface of its own, into a context of its own many times and checks that the interface adds no
;; C function per context. The callables of its methods are code objects that Chez keeps locked for
;; good, so they are made once, when the library is loaded, and shared: a leak shows as one or more
;; per method per context.
(import (chezscheme)
        (crest dialect)
        (mlir IR DialectRegistry) (mlir IR MLIRContext))

(define (code-count)
  (collect 4 4)
  (let ([entry (assq 'code (object-counts))])
    (apply + (map cadr (cdr entry)))))

(define (once)
  (with-DialectRegistry reg ()
    (with-MLIRContext ctx (reg)
      (load-scheme-dialect! ctx "calltest" "passes/call-dialect"))))

(enable-object-counts #t)
(once)
(define before (code-count))
(define runs 100)
(do ([i 0 (+ i 1)]) ((= i runs)) (once))
(define growth (- (code-count) before))
;; The inliner interface has six callables: a leak would be six hundred.
(display (if (< growth runs) "shared" (list "leaked" growth)))
(newline)
