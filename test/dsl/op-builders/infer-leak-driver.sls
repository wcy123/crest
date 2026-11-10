;; scheme-mlir driver: loads the bld dialect (passes/bld-dialect) into a context of its own many
;; times and checks that its InferTypeOpInterface adds no C function per context. The callables of
;; inferReturnTypes and isCompatibleReturnTypes are code objects that Chez keeps locked for good, so
;; they are made once and shared: a leak shows as one or two per op per context.
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
      (load-scheme-dialect! ctx "bld" "passes/bld-dialect"))))

(enable-object-counts #t)
(once)
(define before (code-count))
(define runs 100)
(do ([i 0 (+ i 1)]) ((= i runs)) (once))
(define growth (- (code-count) before))
;; bld has three ops that infer, one with a compatibility clause: a leak would be hundreds.
(display (if (< growth runs) "shared" (list "leaked" growth)))
(newline)
