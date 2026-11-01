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
          (only (chezscheme) iota vector->list list->vector apply max)
          (only (mlir IR Value)
                mlir::Value::getType)
          (only (mlir IR Operation)
                mlir::Operation::getLoc
                mlir::Operation::getOperand
                mlir::Operation::getResult
                mlir::Operation::getNumOperands
                mlir::Operation::getRegion
                mlir::Operation::getAttr
                mlir::Operation::getBlock
                mlir::Operation::moveBefore
                mlir::Operation::setOperands)
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
          (only (mlir IR MLIRContext)
                current-MLIRContext)
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
                mlir::func::FuncOp::getBody
                mlir::func::FuncDialect)
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
          (only (mlir support array-ref) ArrayRef::size ArrayRef::at)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (crest))

  ;;===--------------------------------------------------------------------===;;
  ;; Helpers
  ;;===--------------------------------------------------------------------===;;

  ;; Convert a RankedTensorType to a MemRefType (same shape, same element type).
  (define (%%tensor->memref-type tensor-type)
    (mlir::MemRefType::get tensor-type))

  ;; Allocate a memref before the first op of block; dealloc before the last.
  (define (%%insert-alloc-and-dealloc! rw loc memref-type block)
    (let ([alloc (mlir::memref::AllocOp::create rw loc memref-type)])
      (mlir::Operation::moveBefore alloc (mlir::Block::front block))
      (let ([dealloc (mlir::memref::DeallocOp::create rw loc alloc)])
        (mlir::Operation::moveBefore dealloc (mlir::Block::back block)))
      alloc))

  ;; Lower op to a nest of affine loops over tensor-type's shape.
  ;; body-fn: (nested-builder ivs-carray) → Value to store
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

  (define (%%constant-lower! op operands-ref rw tc)
    (display (string-append "DEBUG: op = " (number->string op) "\n"))
    (let* ([result      (mlir::Operation::getResult op 0)]
           [_           (display (string-append "DEBUG: result = " (number->string result) "\n"))]
           [tensor-type (mlir::Value::getType result)]
           [_           (display (string-append "DEBUG: tensor-type = " (number->string tensor-type) "\n"))]
           [loc         (mlir::Operation::getLoc op)]
           [const-attr  (mlir::Operation::getAttr op "value")]
           [shape       (mlir::RankedTensorType::getShape tensor-type)]
           [memref-type (%%tensor->memref-type tensor-type)]
           [block       (mlir::Operation::getBlock op)]
           [alloc       (%%insert-alloc-and-dealloc! rw loc memref-type block)]
           [ctx         (current-MLIRContext)]
           ;; Pre-allocate constant index ops 0..max(shape).
           [max-dim     (let loop ([i 0] [n (ArrayRef::size shape)] [m 0])
                          (if (>= i n) m
                              (let ([d (ArrayRef::at shape i)])
                                (loop (+ i 1) n (if (> d m) d m)))))]
           [idx-consts  (list->vector
                         (map (lambda (i)
                                (mlir::arith::ConstantIndexOp::create rw loc i))
                              (iota max-dim)))])
      ;; Recursively store each element.
      (let store! ([dim 0] [elem-idx 0] [indices '()])
        (if (eqv? dim (ArrayRef::size shape))
            ;; Base: emit constant and store.
            (let* ([fa    (mlir::DenseElementsAttr::getValueAt<f64> const-attr elem-idx)]
                   [dval  (mlir::FloatAttr::getValueAsDouble fa)]
                   [fattr (mlir::FloatAttr::get<f64> ctx dval)]
                   [cval  (mlir::arith::ConstantOp::create<f64> rw loc fattr)]
                   [ivec  (list->vector indices)])
              (mlir::affine::AffineStoreOp::create rw loc cval alloc ivec)
              (+ elem-idx 1))
            ;; Recurse over this dimension.
            (let dim-loop ([i 0] [ei elem-idx])
              (if (eqv? i (ArrayRef::at shape dim))
                  ei
                  (dim-loop (+ i 1)
                            (store! (+ dim 1) ei
                                    (append indices (list (vector-ref idx-consts i)))))))))
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

  (define (%%add-lower!       op ops rw tc) (%%binary-lower! op ops rw tc mlir::arith::AddFOp::create))
  (define (%%mul-lower!       op ops rw tc) (%%binary-lower! op ops rw tc mlir::arith::MulFOp::create))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.transpose → affine loop nest with reversed IVs for load
  ;;===--------------------------------------------------------------------===;;

  (define (%%transpose-lower! op operands-ref rw tc)
    (let* ([input       (ArrayRef::at operands-ref 0)]
           [tensor-type (mlir::Value::getType (mlir::Operation::getResult op 0))]
           [alloc       (%%lower-op-to-loops! op rw tensor-type
                                              (lambda (nb loc ivs)
                                                ;; Reverse the IV list for the load.
                                                (let* ([n   (ArrayRef::size ivs)]
                                                       [rev (list->vector
                                                             (reverse
                                                              (map (lambda (i) (ArrayRef::at ivs i))
                                                                   (iota n))))])
                                                  (mlir::affine::AffineLoadOp::create nb loc input rev))))])
      (mlir::RewriterBase::replaceOp rw op alloc)
      #t))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.func @main → func.func @main
  ;;===--------------------------------------------------------------------===;;

  (define (%%func-lower! op operands-ref rw tc)
    (let ([name (mlir::StringAttr::getValue (mlir::Operation::getAttr op "sym_name"))])
      (display (string-append "DEBUG: func name = " name "\n"))
      (if (not (string=? name "main"))
          #f
          (let* ([loc      (mlir::Operation::getLoc op)]
                 [ftype    (mlir::TypeAttr::getValue
                            (mlir::Operation::getAttr op "function_type"))]
                 [_        (display (string-append "DEBUG: ftype ptr = " (number->string ftype) "\n"))]
                 [new-func (mlir::func::FuncOp::create rw loc name ftype)]
                 [body     (mlir::func::FuncOp::getBody new-func)]
                 [src-reg  (mlir::Operation::getRegion op 0)]
                 [_        (display "DEBUG: got src-reg\n")])
            (mlir::RewriterBase::inlineRegionBefore rw src-reg body)
            (mlir::RewriterBase::eraseOp rw op)
            #t))))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.return → func.return (void only)
  ;;===--------------------------------------------------------------------===;;

  (define (%%return-lower! op operands-ref rw tc)
    (if (> (mlir::Operation::getNumOperands op) 0)
        (begin (display "DEBUG: return has operands, skipping\n") #f)
        (begin
          (mlir::func::ReturnOp::create rw (mlir::Operation::getLoc op))
          (mlir::RewriterBase::eraseOp rw op)
          #t)))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.print → update operands (tensor → memref); op stays
  ;;===--------------------------------------------------------------------===;;

  (define (%%print-lower! op operands-ref rw tc)
    (mlir::RewriterBase::modifyOpInPlace rw op
                                         (lambda ()
                                           (mlir::Operation::setOperands op operands-ref)))
    #t)

  ;;===--------------------------------------------------------------------===;;
  ;; Registration
  ;;===--------------------------------------------------------------------===;;

  (define (%%toy-to-affine-lower! module-op ctx)
    (with-TypeConverter (tc)
      ;; Tensor types lower to MemRef types; everything else is legal.
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
          (display "DEBUG: calling applyPartialConversion\n")
          (eqv? 1 (mlir::applyPartialConversion module-op target patterns))))))

  ) ;; end library (toy ch5 lower-to-affine)
