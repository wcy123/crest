;; Test driver for scheme-mlir: creates Toy ops without `-> type` and prints the module, so a test can
;; see the result types the ops infer. In C++ Toy the builders of ConstantOp, AddOp, MulOp and
;; TransposeOp do the same.
;;
;; Usage: scheme-mlir infer-result-types.sls <toy/chN/toy>
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext)
        (mlir IR OwningOpRef) (mlir IR Operation)
        (mlir IR Builders) (mlir IR BuiltinOps) (mlir IR Location)
        (mlir IR BuiltinAttributes) (mlir IR BuiltinTypes)
        (only (crest pattern-dsl rewrite) begin-mlir-code)
        (only (crest pattern-dsl keywords) = :))

(let ([lib (car (command-line-arguments))])
  ;; LEAK WARNING: what this makes (the context, the module, the builder) lives in a with- scope and is
  ;; freed when the scope ends. A raw MLIRContext::new, ModuleOp::create or parseSourceFile result that is
  ;; never freed leaked, and exit inside a scope skips the cleanup: raise, and exit at the top (%%quit).
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" lib)
    (with-MLIRContext ctx (reg)
      (with-current-MLIRContext ctx
        (mlir::MLIRContext::getOrLoadDialect ctx "toy")
        (let* ([loc    (mlir::UnknownLoc::get ctx)])
          (with-mlir::OwningOpRef module (mlir::ModuleOp::create loc)
            (let* ([body   (mlir::ModuleOp::getBody module)]
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
              (newline))))))))
