;; Toy Ch5 — partial lowering to Affine+Arith+MemRef+Func dialects.
;; Mirrors mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp
;;
;; Conversion patterns, all define-conversion-pattern; the ops they create are begin-mlir-code
;; forms:
;;   toy.constant   → memref.alloc + affine.store per element
;;   toy.add        → affine.for nest with arith.addf
;;   toy.mul        → affine.for nest with arith.mulf
;;   toy.transpose  → affine.for nest with reversed-index load
;;   toy.func @main → func.func @main
;;   toy.return     → func.return (void only)
;;   toy.print      → operand update (tensor→memref; op kept)
(library (toy ch6 lower-to-affine)
  (export toy:lower-to-affine-pass)
  (import (except (rnrs) =)
          (only (chezscheme) iota)
          (only (mlir IR Value)
                mlir::Value::getType)
          (only (mlir IR Operation)
                mlir::Operation::getLoc
                mlir::Operation::getOperand
                mlir::Operation::getResult
                mlir::Operation::getNumOperands
                mlir::Operation::getAttr
                mlir::Operation::getBlock
                mlir::Operation::setOperands
                mlir::Operation::getContext)
          (only (mlir IR Block)
                mlir::Block::front
                mlir::Block::back)
          (only (mlir IR BuiltinTypes)
                mlir::RankedTensorType::getShape
                mlir::RankedTensorType::getElementType
                mlir::IndexType::get
                mlir::Float64Type::get
                mlir::isa<RankedTensorType>?
                mlir::isa<TensorType>?)
          (only (mlir IR BuiltinAttributes)
                mlir::TypeAttr::getValue
                mlir::AffineMapAttr::get
                mlir::FloatAttr::get<f64>
                mlir::DenseElementsAttr::getNumElements
                mlir::DenseElementsAttr::getValueAt<f64>
                mlir::FloatAttr::getValueAsDouble)
          (only (mlir IR OpImplementation)
                mlir::StringAttr::getValue
                mlir::FunctionType::getNumInputs
                mlir::FunctionType::getNumResults)
          (only (mlir IR PatternMatch)
                mlir::RewriterBase::setInsertionPoint)
          (only (mlir Dialect MemRef IR MemRef)
                mlir::MemRefType::get)
          (only (mlir IR AffineMap) mlir::AffineMap::getMultiDimIdentityMap)
          (only (mlir IR Builders) with-InsertionGuard)
          (only (crest support array-ref) crest::CArrayRef::at crest::CArrayRef::size)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (crest))

  ;;===--------------------------------------------------------------------===;;
  ;; Helpers
  ;;===--------------------------------------------------------------------===;;

  ;; Convert a RankedTensorType to a MemRefType (same shape, same element type).
  (define (%%tensor->memref-type tensor-type)
    (mlir::MemRefType::get tensor-type))

  ;; The identity map of rank n as an attribute: the subscripts of an affine.load or store.
  (define (%%identity-map-attr n)
    (mlir::AffineMapAttr::get (mlir::AffineMap::getMultiDimIdentityMap n)))

  ;; Allocate a memref at the start of the block and free it before the terminator, so it lives
  ;; for the whole function. Returns the alloc Value.
  (define (%%insert-alloc-and-dealloc! rw loc memref-type block)
    (let ([alloc (with-InsertionGuard guard (rw)
                                      (mlir::RewriterBase::setInsertionPoint rw (mlir::Block::front block))
                                      (with-current-OpBuilder rw
                                        (begin-mlir-code
                                            a = memref.alloc ()
                                            (operandSegmentSizes : '(0 0) :i32-array)
                                            :loc loc -> memref-type)))])
      (with-InsertionGuard guard (rw)
                           (mlir::RewriterBase::setInsertionPoint rw (mlir::Block::back block))
                           (with-current-OpBuilder rw
                             (begin-mlir-code
                                 memref.dealloc (alloc) :loc loc)))
      alloc))

  ;; Emit an affine.for nest over shape, with lower bounds 0 and steps 1. The innermost body
  ;; stores the value of (body-fn ivs) into alloc at the induction variables ivs, outermost
  ;; first. The ops go to the ambient builder, and each loop body is a ^bb.
  (define (%%emit-loop-nest! loc ctx shape alloc body-fn)
    (let ([idx (mlir::IndexType::get ctx)])
      (let nest ([dims shape] [ivs '()])
        (if (null? dims)
            (let ([val (body-fn (reverse ivs))]
                  [map (%%identity-map-attr (length ivs))])
              (begin-mlir-code
                  affine.store (val alloc ,@(reverse ivs)) (map : map) :loc loc))
            (begin-mlir-code
                affine.for ()
                (lowerBoundMap : (affine-map-attr () () 0))
                (upperBoundMap : (affine-map-attr () () (car dims)))
                (step : 1 :index)
                (^body ,@(list idx)
                       (nest (cdr dims) (cons (:arg 0) ivs))
                       affine.yield () :loc loc)
                :loc loc)))))

  ;; Allocate the result of an elementwise lowering and fill it with an affine.for nest over
  ;; tensor-type's shape. body-fn: (ivs) → the Value to store. Returns the alloc Value.
  (define (%%lower-op-to-loops! op rw tensor-type body-fn)
    (let* ([loc         (mlir::Operation::getLoc op)]
           [ctx         (mlir::Operation::getContext op)]
           [memref-type (%%tensor->memref-type tensor-type)]
           [alloc       (%%insert-alloc-and-dealloc! rw loc memref-type (mlir::Operation::getBlock op))])
      (with-current-OpBuilder rw
        (%%emit-loop-nest! loc ctx (mlir::RankedTensorType::getShape tensor-type) alloc body-fn))
      alloc))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.constant → memref.alloc + affine.store per element
  ;;===--------------------------------------------------------------------===;;

  ;; Walk all elements of a DenseElementsAttr and store each as an arith.constant. Each store
  ;; subscripts alloc with index constants, one per position along each dimension.
  (define (%%store-const-elements! loc ctx const-attr shape alloc)
    (let* ([idx        (mlir::IndexType::get ctx)]
           [f64        (mlir::Float64Type::get ctx)]
           [max-dim    (apply max 0 shape)]
           [idx-consts (map (lambda (i)
                              (begin-mlir-code
                                  c = arith.constant () (value : i :index) :loc loc -> idx))
                            (iota max-dim))])
      (define (store! dim elem-idx indices)
        (if (eqv? dim (length shape))
            (let* ([fa    (mlir::DenseElementsAttr::getValueAt<f64> const-attr elem-idx)]
                   [fattr (mlir::FloatAttr::get<f64> ctx (mlir::FloatAttr::getValueAsDouble fa))]
                   [map   (%%identity-map-attr (length indices))])
              (begin-mlir-code
                  c = arith.constant () (value : fattr) :loc loc -> f64
                  affine.store (c alloc ,@indices) (map : map) :loc loc)
              (+ elem-idx 1))
            (let loop ([i 0] [ei elem-idx])
              (if (eqv? i (list-ref shape dim))
                  ei
                  (loop (+ i 1)
                        (store! (+ dim 1) ei
                                (append indices (list (list-ref idx-consts i)))))))))
      (store! 0 0 '())))

  (define-conversion-pattern (%%constant-lower! op operands-ref rw tc)
    :if-match
      %out = toy.constant ()
    :then-let
      ([loc         (mlir::Operation::getLoc op)]
       [ctx         (mlir::Operation::getContext op)]
       [tensor-type (mlir::Value::getType %out)])
    :rewrite %out :with
      alloc = (%%insert-alloc-and-dealloc! rw loc (%%tensor->memref-type tensor-type)
                                           (mlir::Operation::getBlock op))
      (%%store-const-elements! loc ctx (mlir::Operation::getAttr op "value")
                               (mlir::RankedTensorType::getShape tensor-type) alloc)
      alloc)

  ;;===--------------------------------------------------------------------===;;
  ;; toy.add / toy.mul → affine loop nest
  ;;===--------------------------------------------------------------------===;;

  ;; Load lhs and rhs at the induction variables and combine them with arith.addf (kind add) or
  ;; arith.mulf (kind mul). Returns the alloc Value.
  (define (%%binary-lower! op rw lhs rhs kind)
    (let* ([tensor-type (mlir::Value::getType (mlir::Operation::getResult op 0))]
           [elem-type   (mlir::RankedTensorType::getElementType tensor-type)]
           [loc         (mlir::Operation::getLoc op)])
      (%%lower-op-to-loops!
       op rw tensor-type
       (lambda (ivs)
         (let ([map (%%identity-map-attr (length ivs))])
           (begin-mlir-code
               ;; lhs is loaded first, as LowerToAffineLoops.cpp does
               l = affine.load (lhs ,@ivs) (map : map) :loc loc -> elem-type
               r = affine.load (rhs ,@ivs) (map : map) :loc loc -> elem-type
               (case kind
                 [(add) (begin-mlir-code v = arith.addf (l r) :loc loc)]
                 [(mul) (begin-mlir-code v = arith.mulf (l r) :loc loc)])))))))

  (define-conversion-pattern (%%add-lower! op operands-ref rw tc)
    :if-match
      %sum = toy.add (%lhs %rhs)
    :rewrite %sum :with
      (%%binary-lower! op rw %lhs %rhs 'add))

  (define-conversion-pattern (%%mul-lower! op operands-ref rw tc)
    :if-match
      %product = toy.mul (%lhs %rhs)
    :rewrite %product :with
      (%%binary-lower! op rw %lhs %rhs 'mul))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.transpose → affine loop nest with reversed IVs for load
  ;;===--------------------------------------------------------------------===;;

  (define-conversion-pattern (%%transpose-lower! op operands-ref rw tc)
    :if-match
      %out = toy.transpose (%in)
    :then-let
      ([tensor-type (mlir::Value::getType %out)]
       [elem-type   (mlir::RankedTensorType::getElementType (mlir::Value::getType %out))]
       [loc         (mlir::Operation::getLoc op)])
    :rewrite %out :with
      (%%lower-op-to-loops!
       op rw tensor-type
       (lambda (ivs)
         (let ([map (%%identity-map-attr (length ivs))])
           (begin-mlir-code
               v = affine.load (%in ,@(reverse ivs)) (map : map) :loc loc -> elem-type)))))

  ;;===--------------------------------------------------------------------===;;
  ;; toy.func @main → func.func @main
  ;;===--------------------------------------------------------------------===;;

  ;; Only `main`, with no inputs and no results, is lowered (C++ FuncOpLowering: "expected 'main'
  ;; to have 0 inputs and 0 results").
  (define (%%empty-signature? function-type)
    (and (eqv? 0 (mlir::FunctionType::getNumInputs function-type))
         (eqv? 0 (mlir::FunctionType::getNumResults function-type))))

  (define-conversion-pattern (%%func-lower! op operands-ref rw tc)
    :if-match
      toy.func ()
        :where (and (string=? "main" (mlir::StringAttr::getValue (:attr "sym_name")))
                    (%%empty-signature? (mlir::TypeAttr::getValue (:attr "function_type"))))
    :rewrite op :with
      func.func ()
      (sym_name : (mlir::Operation::getAttr op "sym_name"))
      (function_type : (mlir::Operation::getAttr op "function_type"))
      (:move-region op)
    :loc (mlir::Operation::getLoc op))

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
    (apply-conversion module-op ctx
                      :mode partial
                      ;; Tensor types lower to MemRef types; everything else passes through.
                      :type-converter (lambda (type)
                                        (if (mlir::isa<RankedTensorType>? type)
                                            (%%tensor->memref-type type)
                                            type))
                      :legal-dialects ("affine" "arith" "func" "memref" "builtin")
                      :illegal-dialects ("toy")
                      ;; toy.print is legal once its operand is a memref (not a tensor).
                      :dynamically-legal (("toy.print"
                                           (lambda (print-op)
                                             (not (mlir::isa<TensorType>?
                                                   (mlir::Value::getType
                                                    (mlir::Operation::getOperand print-op 0)))))))
                      :patterns (("toy.constant"  %%constant-lower!)
                                 ("toy.add"       %%add-lower!)
                                 ("toy.mul"       %%mul-lower!)
                                 ("toy.transpose" %%transpose-lower!)
                                 ("toy.func"      %%func-lower!)
                                 ("toy.return"    %%return-lower!)
                                 ("toy.print"     %%print-lower!))))

  ;; ToyToAffineLoweringPass: partially lowers the toy dialect; fails when the conversion does.
  (define-pass (toy:lower-to-affine-pass module)
    (let ([ctx (mlir::Operation::getContext module)])
      (with-current-MLIRContext ctx
        (%%toy-to-affine-lower! module ctx))))

  ) ;; end library (toy ch6 lower-to-affine)
