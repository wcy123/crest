;; scheme-mlir driver: the bindings that make ops of the arith, memref and scf dialects, and the blocks around them, used
;; to build the body of a function that is printed. Each of them was named by no other test.
;; (func.func and func.return are made with a rewriter: rewriter-creators.sls.)
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef) (mlir IR Operation)
        (mlir IR Value) (mlir IR Block) (mlir IR Region) (mlir IR Builders) (mlir IR BuiltinOps)
        (mlir IR Location) (mlir IR BuiltinTypes) (mlir IR BuiltinAttributes)
        (mlir Dialect Func IR FuncOps) (mlir Dialect Arith IR Arith)
        (mlir Dialect MemRef IR MemRef) (mlir Dialect SCF IR SCFOps) (mlir Dialect SCF IR SCFDialect) (mlir Support WalkResult)
        (only (crest pattern-dsl rewrite) begin-mlir-code)
        (only (crest pattern-dsl keywords) = : ->))

(define (find-op module name)
  (let ([found 0])
    (mlir::Operation::walk module
                           (lambda (op) (when (equal? (mlir::Operation::getName op) name) (set! found op))
                                   #t mlir::WalkResult::advance))
    found))

(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
  (mlir::DialectRegistry::insert<mlir::arith::ArithDialect> reg)
  (mlir::DialectRegistry::insert<mlir::memref::MemRefDialect> reg)
  (mlir::DialectRegistry::insert<mlir::scf::SCFDialect> reg)
  (with-MLIRContext ctx (reg)
    (with-current-MLIRContext ctx
      (for-each (lambda (name) (mlir::MLIRContext::getOrLoadDialect ctx name)) '("func" "arith" "memref" "scf"))
      (let ([loc (mlir::UnknownLoc::get ctx)]
            [f64 (mlir::Float64Type::get)])
        (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car (command-line-arguments)))
          (let* ([function (find-op module "func.func")]
                 [entry (mlir::Region::emplaceBlock (mlir::func::FuncOp::getBody function))]
                 [x (mlir::Block::addArgument entry f64 loc)])
            (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd entry)
              (let* ([c0 (mlir::arith::ConstantIndexOp::create builder loc 0)]
                     [c4 (mlir::arith::ConstantIndexOp::create builder loc 4)]
                     [c1 (mlir::arith::ConstantIndexOp::create builder loc 1)]
                     [two (mlir::arith::ConstantOp::create<f64> builder loc (mlir::FloatAttr::get<f64> 2.5))]
                     [sum (mlir::arith::AddFOp::create builder loc x two)]
                     [product (mlir::arith::MulFOp::create builder loc sum x)]
                     [memref-type (mlir::MemRefType::get (mlir::TypeAttr::getValue (mlir::parseAttribute "tensor<4xf64>")))]
                     [buffer (mlir::memref::AllocOp::create builder loc memref-type)]
                     [loaded (mlir::memref::LoadOp::create builder loc buffer (list c0))]
                     [loop (mlir::scf::ForOp::create builder loc c0 c4 c1)])
                (with-OpBuilder body-builder (mlir::OpBuilder::atBlockEnd (mlir::scf::ForOp::getBody loop))
                  (mlir::scf::YieldOp::create body-builder loc))
                (mlir::memref::DeallocOp::create builder loc buffer)
                (with-current-OpBuilder builder
                  (begin-mlir-code func.return ()))
                (display (if (zero? (mlir::scf::ForOp::getInductionVar loop)) "no induction variable" "induction variable: yes"))
                (newline)))
            (display (mlir::Operation::print module))))))))
