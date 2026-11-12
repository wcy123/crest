;; Test driver for scheme-mlir: calls the two callbacks a Scheme dialect gives MLIR for creating
;; ops, the way MLIR's passes would, so a test can see what they create.
;;
;; Usage: scheme-mlir materialize.sls <toy/chN/toy> <constant|cast> [input.mlir]
;;   constant  Dialect::materializeConstant with a dense tensor attribute
;;   cast      the inliner interface's materializeCallConversion on the first op's result of
;;             input.mlir, to the unranked tensor<*xf64>
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext)
        (mlir IR OwningOpRef) (mlir IR Operation)
        (mlir IR Builders) (mlir IR BuiltinOps) (mlir IR Block) (mlir IR Location)
        (mlir IR BuiltinAttributes) (mlir IR Dialect) (mlir Transforms InliningUtils))

(define (%%type text)
  (mlir::TypeAttr::getValue (mlir::parseAttribute text)))

(let* ([args    (command-line-arguments)]
       [lib     (car args)]
       [mode    (cadr args)])
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert reg "toy" lib)
    (with-MLIRContext ctx (reg)
      (with-current-MLIRContext ctx
        (let* ([dialect (mlir::MLIRContext::getOrLoadDialect ctx "toy")]
               [loc     (mlir::UnknownLoc::get ctx)])
          (with-mlir::OwningOpRef module (if (string=? mode "cast")
                                             (mlir::parseSourceFile ctx (caddr args))
                                             (mlir::ModuleOp::create loc))
            (let* ([body    (mlir::ModuleOp::getBody module)])
              (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd body)
                (let ([op (if (string=? mode "constant")
                              (mlir::Dialect::materializeConstant
                               builder dialect
                               (mlir::parseAttribute "dense<[1.0, 2.0]> : tensor<2xf64>")
                               (%%type "tensor<2xf64>") loc)
                              (mlir::DialectInlinerInterface::materializeCallConversion
                               builder dialect
                               (mlir::Operation::getResult (mlir::Block::front body) 0)
                               (%%type "tensor<*xf64>") loc))])
                  (display (mlir::Operation::print op))
                  (newline))))))))))
