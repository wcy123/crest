;; Test driver for scheme-mlir: creates Toy ops without `-> type` and prints the module, so a test can
;; see the result types the ops infer. In C++ Toy the builders of ConstantOp, AddOp, MulOp and
;; TransposeOp do the same.
;;
;; Usage: scheme-mlir infer-result-types.sls <toy/chN/toy>
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation)
        (mlir IR Builders) (mlir IR BuiltinOps) (mlir IR Location)
        (mlir IR BuiltinAttributes) (mlir IR BuiltinTypes)
        (only (crest pattern-dsl rewrite) begin-mlir-code)
        (only (crest pattern-dsl keywords) = :))

(let ([lib (car (command-line-arguments))])
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" lib)
    (with-MLIRContext ctx (reg)
      (with-current-MLIRContext ctx
        (mlir::MLIRContext::getOrLoadDialect ctx "toy")
        (let* ([loc    (mlir::UnknownLoc::get ctx)]
               [module (mlir::ModuleOp::create loc)]
               [body   (mlir::ModuleOp::getBody module)]
               [type   (mlir::RankedTensorType::get '(2 1) (mlir::Float64Type::get))]
               [attr   (mlir::DenseElementsAttr::get<f64> type (list 1.0 2.0))])
          (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd body)
            (with-current-OpBuilder builder
              (begin-mlir-code
                  c = toy.constant () (value : attr)
                  a = toy.add (c c)
                  m = toy.mul (c c)
                  t = toy.transpose (c))))
          (display (mlir::Operation::print module))
          (newline))))))
