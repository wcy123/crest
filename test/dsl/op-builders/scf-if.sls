;; Test driver for scheme-mlir: creates an scf.if with its two regions, with the result type written
;; (`explicit`) or left out (`inferred`).
;;
;; Usage: scheme-mlir scf-if.sls <explicit|inferred>
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation)
        (mlir Dialect Arith IR Arith) (mlir Dialect SCF IR SCFDialect)
        (mlir IR Builders) (mlir IR BuiltinOps) (mlir IR Location) (mlir IR BuiltinTypes)
        (only (crest pattern-dsl rewrite) begin-mlir-code)
        (only (crest pattern-dsl keywords) = : -> :i64))

(define mode (car (command-line-arguments)))

(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert<mlir::arith::ArithDialect> reg)
  (mlir::DialectRegistry::insert<mlir::scf::SCFDialect> reg)
  (with-MLIRContext ctx (reg)
    (with-current-MLIRContext ctx
      (mlir::MLIRContext::getOrLoadDialect ctx "arith")
      (mlir::MLIRContext::getOrLoadDialect ctx "scf")
      (let* ([loc    (mlir::UnknownLoc::get ctx)]
             [module (mlir::ModuleOp::create loc)]
             [body   (mlir::ModuleOp::getBody module)]
             [i64    (mlir::IntegerType::get<i64>)])
        (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd body)
          (with-current-OpBuilder builder
            (if (string=? mode "explicit")
                (begin-mlir-code
                    c = arith.constant () (value : 1 :i64) -> i64
                    r = scf.if (c)
                    (^then () a = arith.constant () (value : 2 :i64) -> i64 scf.yield (a))
                    (^else () b = arith.constant () (value : 3 :i64) -> i64 scf.yield (b))
                    -> i64)
                (begin-mlir-code
                    c = arith.constant () (value : 1 :i64) -> i64
                    r = scf.if (c)
                    (^then () a = arith.constant () (value : 2 :i64) -> i64 scf.yield (a))
                    (^else () b = arith.constant () (value : 3 :i64) -> i64 scf.yield (b))))))
        (display (mlir::Operation::print module))
        (newline)))))
