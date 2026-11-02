;; Toy Ch5 — partial lowering to Affine+Arith+MemRef+Func dialects.
;; Mirrors mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp
;;
;; Conversion patterns (plain Scheme callbacks, not DDR):
;;   toy.constant   → memref.alloc + affine.store per element
;;   toy.add        → affine.for nest with arith.addf
;;   toy.mul        → affine.for nest with arith.mulf
;;   toy.transpose  → affine.for nest with reversed-index load
;;   toy.func @main → func.func @main
;;   toy.return     → func.return (void only)
;;   toy.print      → operand update (tensor→memref; op kept)
(library (toy ch5 lower-to-affine)
  (export %%toy-to-affine-lower!)
  (import (except (rnrs) =)
          (only (chezscheme) iota)
          (only (mlir IR Value)
                mlir::Value::getType
                mlir::Value::getDefiningOp)
          (only (mlir IR Operation)
                mlir::Operation::getLoc
                mlir::Operation::getOperand
                mlir::Operation::getResult
                mlir::Operation::getNumOperands
                mlir::Operation::getRegion
                mlir::Operation::getAttr
                mlir::Operation::getBlock
                mlir::Operation::moveBefore
                mlir::Operation::setOperands
                mlir::Operation::getContext)
          (only (mlir IR Block)
                mlir::Block::front
                mlir::Block::back)
          (only (mlir IR BuiltinTypes)
                mlir::RankedTensorType::getShape
                mlir::RankedTensorType::getElementType
                mlir::isa<RankedTensorType>?)
          (only (mlir IR BuiltinAttributes)
                mlir::TypeAttr::getValue
                mlir::FloatAttr::get<f64>
                mlir::DenseElementsAttr::getNumElements
                mlir::DenseElementsAttr::getValueAt<f64>
                mlir::FloatAttr::getValueAsDouble)
          (only (mlir IR OpImplementation)
                mlir::StringAttr::getValue)
          (only (mlir IR PatternMatch)
                mlir::RewriterBase::replaceOp
                mlir::RewriterBase::eraseOp)
          (only (mlir Dialect Affine IR AffineOps)
                mlir::affine::buildAffineLoopNest
                mlir::affine::AffineLoadOp::create
                mlir::affine::AffineStoreOp::create)
          (only (mlir Dialect Arith IR Arith)
                mlir::arith::AddFOp::create
                mlir::arith::MulFOp::create
                mlir::arith::ConstantIndexOp::create
                mlir::arith::ConstantOp::create<f64>)
          (only (mlir Dialect MemRef IR MemRef)
                mlir::MemRefType::get
                mlir::memref::AllocOp::create
                mlir::memref::DeallocOp::create)
          (only (mlir Dialect Func IR FuncOps)
                mlir::func::FuncOp::create
                mlir::func::ReturnOp::create
                mlir::func::FuncOp::getBody)
          (only (mlir Transforms DialectConversion)
                target-create
                target-add-illegal-dialect
                target-add-legal-dialect
                target-add-dynamically-legal-op
                mlir::applyPartialConversion
                mlir::RewriterBase::modifyOpInPlace
                mlir::RewriterBase::inlineRegionBefore
                type-converter-add-conversion
                add-conversion-pattern
                with-TypeConverter
                with-ConversionTarget)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir support array-ref) ArrayRef::at ArrayRef::size)
          (crest))

  ;;===--------------------------------------------------------------------===;;
  ;; Helpers
  ;;===--------------------------------------------------------------------===;;

  ;; Convert a RankedTensorType to a MemRefType (same shape, same element type).
  (define (%%tensor->memref-type tensor-type)
    (mlir::MemRefType::get tensor-type))

  ;; Allocate a memref before the first op of block; dealloc before the last.
  ;; Returns the alloc Value.
  (define (%%insert-alloc-and-dealloc! rw loc memref-type block)
    (let* ([alloc-val  (mlir::memref::AllocOp::create rw loc memref-type)]
           [alloc-op   (mlir::Value::getDefiningOp alloc-val)]
           [dealloc-op (mlir::memref::DeallocOp::create rw loc alloc-val)])
      (mlir::Operation::moveBefore alloc-op  (mlir::Block::front block))
      (mlir::Operation::moveBefore dealloc-op (mlir::Block::back  block))
      alloc-val))

  ;; Lower op to a nest of affine loops over tensor-type's shape.
  ;; body-fn: (nested-builder ivs-list) → Value to store
  ;; Returns the alloc Value.
  (define (%%lower-op-to-loops! op rw tensor-type body-fn)
    (let* ([loc         (mlir::Operation::getLoc op)]
           [memref-type (%%tensor->memref-type tensor-type)]
           [block       (mlir::Operation::getBlock op)]
           [alloc       (%%insert-alloc-and-dealloc! rw loc memref-type block)]
           [shape       (mlir::RankedTensorType::getShape tensor-type)])
      (mlir::affine::buildAffineLoopNest
       rw loc shape
       (lambda (nb ivs)
         (let ([val (body-fn nb loc ivs)])
           (mlir::affine::AffineStoreOp::create nb loc val alloc ivs))))
      alloc))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.constant → memref.alloc + affine.store per element
  ;;===--------------------------------------------------------------------===;;

  ;; Walk all elements of a DenseElementsAttr and store each as an arith.constant.
  (define (%%store-const-elements! rw loc const-attr shape alloc idx-consts ctx)
    (define (store! dim elem-idx indices)
      (if (eqv? dim (length shape))
          (let* ([fa    (mlir::DenseElementsAttr::getValueAt<f64> const-attr elem-idx)]
                 [dval  (mlir::FloatAttr::getValueAsDouble fa)]
                 [fattr (mlir::FloatAttr::get<f64> ctx dval)]
                 [cval  (mlir::arith::ConstantOp::create<f64> rw loc fattr)])
            (mlir::affine::AffineStoreOp::create rw loc cval alloc indices)
            (+ elem-idx 1))
          (let loop ([i 0] [ei elem-idx])
            (if (eqv? i (list-ref shape dim))
                ei
                (loop (+ i 1)
                      (store! (+ dim 1) ei
                              (append indices (list (list-ref idx-consts i)))))))))
    (store! 0 0 '()))

  (define (%%constant-lower! op operands-ref rw tc)
    (let* ([result      (mlir::Operation::getResult op 0)]
           [tensor-type (mlir::Value::getType result)]
           [loc         (mlir::Operation::getLoc op)]
           [const-attr  (mlir::Operation::getAttr op "value")]
           [shape       (mlir::RankedTensorType::getShape tensor-type)]
           [memref-type (%%tensor->memref-type tensor-type)]
           [block       (mlir::Operation::getBlock op)]
           [alloc       (%%insert-alloc-and-dealloc! rw loc memref-type block)]
           [ctx         (mlir::Operation::getContext op)]
           [max-dim     (apply max 0 shape)]
           [idx-consts  (map (lambda (i) (mlir::arith::ConstantIndexOp::create rw loc i))
                             (iota max-dim))])
      (%%store-const-elements! rw loc const-attr shape alloc idx-consts ctx)
      (mlir::RewriterBase::replaceOp rw op alloc)
      #t))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.add / toy.mul → affine loop nest
  ;;===--------------------------------------------------------------------===;;

  (define (%%binary-lower! op operands-ref rw tc arith-create)
    (let* ([lhs         (ArrayRef::at operands-ref 0)]
           [rhs         (ArrayRef::at operands-ref 1)]
           [tensor-type (mlir::Value::getType (mlir::Operation::getResult op 0))]
           [alloc       (%%lower-op-to-loops! op rw tensor-type
                                              (lambda (nb loc ivs)
                                                (let ([l (mlir::affine::AffineLoadOp::create nb loc lhs ivs)]
                                                      [r (mlir::affine::AffineLoadOp::create nb loc rhs ivs)])
                                                  (arith-create nb loc l r))))])
      (mlir::RewriterBase::replaceOp rw op alloc)
      #t))

  (define (%%add-lower! op ops rw tc) (%%binary-lower! op ops rw tc mlir::arith::AddFOp::create))
  (define (%%mul-lower! op ops rw tc) (%%binary-lower! op ops rw tc mlir::arith::MulFOp::create))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.transpose → affine loop nest with reversed IVs for load
  ;;===--------------------------------------------------------------------===;;

  (define (%%transpose-lower! op operands-ref rw tc)
    (let* ([input       (ArrayRef::at operands-ref 0)]
           [tensor-type (mlir::Value::getType (mlir::Operation::getResult op 0))]
           [alloc       (%%lower-op-to-loops! op rw tensor-type
                                              (lambda (nb loc ivs)
                                                (mlir::affine::AffineLoadOp::create
                                                 nb loc input (reverse ivs))))])
      (mlir::RewriterBase::replaceOp rw op alloc)
      #t))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.func @main → func.func @main
  ;;===--------------------------------------------------------------------===;;

  (define (%%func-lower! op operands-ref rw tc)
    (let ([name (mlir::StringAttr::getValue (mlir::Operation::getAttr op "sym_name"))])
      (if (not (string=? name "main"))
          #f
          (let* ([loc      (mlir::Operation::getLoc op)]
                 [ftype    (mlir::TypeAttr::getValue
                            (mlir::Operation::getAttr op "function_type"))]
                 [new-func (mlir::func::FuncOp::create rw loc name ftype)]
                 [body     (mlir::func::FuncOp::getBody new-func)]
                 [src-reg  (mlir::Operation::getRegion op 0)])
            (mlir::RewriterBase::inlineRegionBefore rw src-reg body)
            (mlir::RewriterBase::eraseOp rw op)
            #t))))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.return → func.return (void only)
  ;;===--------------------------------------------------------------------===;;

  (define-conversion-pattern (%%return-lower! op operands-ref rw tc)
    :if-match
      toy.return ()
        :where (eqv? 0 (mlir::Operation::getNumOperands op))
    :rewrite op :with
      func.return ())

  ;;===--------------------------------------------------------------------===;;
  ;; toy.print → update operands (tensor → memref); op stays
  ;; %in is bound to the type-converted operand via operands-ref.
  ;;===--------------------------------------------------------------------===;;

  (define-conversion-pattern (%%print-lower! op operands-ref rw tc)
    :if-match
      toy.print (%in)
    :rewrite op :with
      toy.print (%in))

  ;;===--------------------------------------------------------------------===;;
  ;; Registration
  ;;===--------------------------------------------------------------------===;;

  (define (%%toy-to-affine-lower! module-op ctx)
    (with-TypeConverter (tc)
      ;; Tensor types lower to MemRef types; everything else passes through.
      (type-converter-add-conversion tc
                                     (lambda (type)
                                       (if (mlir::isa<RankedTensorType>? type)
                                           (%%tensor->memref-type type)
                                           type)))
      (with-ConversionTarget (target ctx)
        (target-add-legal-dialect target "affine")
        (target-add-legal-dialect target "arith")
        (target-add-legal-dialect target "func")
        (target-add-legal-dialect target "memref")
        (target-add-legal-dialect target "builtin")
        (target-add-illegal-dialect target "toy")
        ;; toy.print is legal once its operand is a memref (not a tensor).
        (target-add-dynamically-legal-op target ctx "toy.print"
                                         (lambda (print-op)
                                           (not (mlir::isa<RankedTensorType>?
                                                 (mlir::Value::getType
                                                  (mlir::Operation::getOperand print-op 0))))))
        (with-RewritePatternSet (patterns ctx)
          (add-conversion-pattern patterns "toy.constant" %%constant-lower!  tc 1)
          (add-conversion-pattern patterns "toy.add"      %%add-lower!       tc 1)
          (add-conversion-pattern patterns "toy.mul"      %%mul-lower!       tc 1)
          (add-conversion-pattern patterns "toy.transpose" %%transpose-lower! tc 1)
          (add-conversion-pattern patterns "toy.func"     %%func-lower!      tc 1)
          (add-conversion-pattern patterns "toy.return"   %%return-lower!    tc 1)
          (add-conversion-pattern patterns "toy.print"    %%print-lower!     tc 1)
          (eqv? 1 (mlir::applyPartialConversion module-op target patterns))))))

  ) ;; end library (toy ch5 lower-to-affine)
