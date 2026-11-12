;; Test driver for scheme-mlir: creates C++ ops without `-> type` and prints the module. arith.addi
;; and arith.mulf implement InferTypeOpInterface (through SameOperandsAndResultType), so the result
;; type comes from the operands; the two constants name theirs, as arith.constant has no operand.
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext)
        (mlir IR OwningOpRef) (mlir IR Operation)
        (mlir Dialect Arith IR Arith) (mlir IR Builders) (mlir IR BuiltinOps) (mlir IR Location) (mlir IR BuiltinTypes)
        (only (crest pattern-dsl rewrite) begin-mlir-code)
        (only (crest pattern-dsl keywords) = : -> :i64 :f64))

(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert<mlir::arith::ArithDialect> reg)
  (with-MLIRContext ctx (reg)
    (with-current-MLIRContext ctx
      (mlir::MLIRContext::getOrLoadDialect ctx "arith")
      (let* ([loc    (mlir::UnknownLoc::get ctx)])
        (with-mlir::OwningOpRef module (mlir::ModuleOp::create loc)
          (let* ([body   (mlir::ModuleOp::getBody module)]
                 [i64    (mlir::IntegerType::get<i64>)]
                 [f64    (mlir::Float64Type::get)])
            (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd body)
              (with-current-OpBuilder builder
                (begin-mlir-code
                    a = arith.constant () (value : 2 :i64) -> i64
                    b = arith.constant () (value : 1.5 :f64) -> f64
                    s = arith.addi (a a)
                    p = arith.mulf (b b))))
            (display (mlir::Operation::print module))
            (newline)))))))
