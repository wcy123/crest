;; scheme-mlir driver: walks a module and builds a loop nest many times, each on a context of its
;; own, and checks that the C functions made for the callbacks are released when the call returns.
;; They are code objects that Chez keeps locked until C++ unlocks them: a leak shows as one per call.
(import (except (rnrs) =)
        (only (chezscheme) collect object-counts enable-object-counts command-line-arguments)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR OwningOpRef)
        (only (mlir IR Region) mlir::Region::front)
        (only (mlir IR Builders) with-OpBuilder mlir::OpBuilder::atBlockEnd)
        (only (mlir Dialect Affine IR AffineOps)
              mlir::DialectRegistry::insert<mlir::affine::AffineDialect>
              mlir::affine::buildAffineLoopNest))

(define (code-count)
  (collect 4 4)
  (let ([entry (assq 'code (object-counts))])
    (apply + (map cadr (cdr entry)))))

(define path (car (command-line-arguments)))

(define (once)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert<mlir::affine::AffineDialect> reg)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::getOrLoadDialect ctx "affine")
      (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx path)
        (mlir::Operation::walk module (lambda (op) #t))
        (with-current-MLIRContext ctx
          (let ([block (mlir::Region::front (mlir::Operation::getRegion module 0))])
            (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd block)
              (mlir::affine::buildAffineLoopNest
               builder (mlir::Operation::getLoc module) '(0) '(4) '(1)
               (lambda (nested-builder loc ivs) #t)))))))))

(enable-object-counts #t)
(once)
(define before (code-count))
(define runs 100)
(do ([i 0 (+ i 1)]) ((= i runs)) (once))
(define growth (- (code-count) before))
;; A run makes two callables (the walk, the loop nest): a leak would be two hundred.
(display (if (< growth runs) "released" (list "leaked" growth)))
(newline)
