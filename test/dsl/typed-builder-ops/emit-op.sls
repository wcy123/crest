;; Test driver for scheme-mlir: replaces every test.k op in the input module with one op
;; emitted by begin-mlir-code, then runs the verifier (through a pass manager) and prints
;; the module.
;;
;; affine.load needs a `map` attribute: an AffineMapAttr built from an AffineMap. The maps are
;; written with the affine-map macro; the `maps` case instead calls the C++-mirroring bindings
;; directly. The MLIRContext argument is optional and defaults to (current-MLIRContext).
;;
;; Usage: scheme-mlir emit-op.sls <input.mlir> <memref.load|affine.load|maps|exprs>
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR Value)
        (mlir IR PatternMatch) (mlir IR Builders)
        (mlir Transforms GreedyPatternRewriteDriver) (mlir Transforms DialectConversion)
        (mlir Transforms Passes) (mlir Pass PassManager) (mlir IR BuiltinAttributes) (mlir IR AffineMap)
        (mlir Dialect Affine IR AffineOps) (mlir Dialect Arith IR Arith)
        (mlir Dialect MemRef IR MemRef) (mlir Dialect Func IR FuncOps)
        (crest))

;; test.k(%memref, %index) -> OP(%memref, %index)
(define (%%make-rewrite which)
  (lambda (op rw)
    (let* ([bld (crest::as_ptr<mlir::OpBuilder> rw)]
           [m   (mlir::Operation::getOperand op 0)]
           [i   (mlir::Operation::getOperand op 1)]
           [ty  (mlir::Value::getType (mlir::Operation::getResult op 0))])
      (mlir::RewriterBase::setInsertionPoint rw op)
      (let ([r (with-current-OpBuilder bld
                 (cond
                  [(string=? which "memref.load")
                   (begin-mlir-code r = memref.load (m i) -> ty)]
                  [(string=? which "affine.load")
                   (begin-mlir-code
                       r = affine.load (m i)
                       (map : (mlir::AffineMapAttr::get (affine-map (d0) () d0)))
                       -> ty)]
                  ;; The other AffineMap and AffineMapAttr bindings, as attributes on an
                  ;; unregistered op: a constant map, the empty map, and a map read back
                  ;; from an AffineMapAttr with getValue.
                  [(string=? which "maps")
                   (let ([attr (mlir::AffineMapAttr::get
                                (mlir::AffineMap::getMultiDimIdentityMap 2))])
                     (begin-mlir-code
                         r = test.maps (m i)
                         (c : (mlir::AffineMapAttr::get (mlir::AffineMap::getConstantMap 7)))
                         (e : (mlir::AffineMapAttr::get (mlir::AffineMap::get 0 0 '())))
                         (rt : (mlir::AffineMapAttr::get (mlir::AffineMapAttr::getValue attr)))
                         -> ty))]
                  ;; affine-map: every operator, names independent of the printed d0 and s0,
                  ;; Scheme variables in the body (t, u), integer-only arithmetic that stays a
                  ;; number, negation, and a map with no results.
                  [(string=? which "exprs")
                   (let ([t 4] [u 3])
                     (begin-mlir-code
                         r = test.exprs (m i)
                         (a : (mlir::AffineMapAttr::get (affine-map (d0 d1) (s0) (+ d0 s0) d1)))
                         (b : (mlir::AffineMapAttr::get (affine-map (i) () (floordiv i t) (mod i t))))
                         (c : (mlir::AffineMapAttr::get (affine-map (d0 d1) () (- d0 d1) (* 2 d1))))
                         (ce : (mlir::AffineMapAttr::get (affine-map (d0) () (ceildiv d0 u))))
                         (n : (mlir::AffineMapAttr::get (affine-map () () (* 2 u))))
                         (neg : (mlir::AffineMapAttr::get (affine-map (d0) () (- d0))))
                         (z : (mlir::AffineMapAttr::get (affine-map (d0 d1) (s0))))
                         -> ty))]
                  [else (error 'emit-op "unknown op" which)]))])
        (mlir::RewriterBase::replaceOp rw op r)
        #t))))

(let* ([args  (command-line-arguments)]
       [file  (car args)]
       [which (cadr args)])
  (with-DialectRegistry reg ()
    (mlir::affine::AffineDialect reg)
    (mlir::arith::ArithDialect reg)
    (mlir::memref::MemRefDialect reg)
    (mlir::func::FuncDialect reg)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
      (for-each (lambda (d) (mlir::MLIRContext::getOrLoadDialect ctx d))
                '("affine" "arith" "memref" "func"))
      (let ([module-op (mlir::parseSourceFile ctx file)])
        (with-current-MLIRContext ctx
          (with-RewritePatternSet ps (ctx)
            (add-rewrite-pattern ps "test.k" (%%make-rewrite which) 10)
            (mlir::applyPatternsGreedily module-op ps)))
        (with-PassManager pm (ctx)
          (mlir::PassManager::addPass pm (mlir::createCanonicalizerPass))
          (if (mlir::PassManager::run! pm module-op)
              (begin (display (mlir::Operation::print module-op)) (newline))
              (begin (display "verification failed\n") (exit 1))))))))
