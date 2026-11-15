;; scheme-mlir driver: the small bindings of types, attributes and the context that no other test named: the types f16,
;; bf16, none and i1; the element type of a complex and of a vector; the rank of a vector; the memory space of a memref;
;; the predicates isa<FloatAttr> and isa<StringAttr>; a flat symbol reference and its name; a float attribute of an op; and
;; the flags of the context (unregistered dialects, threads, the op that a diagnostic prints). argv[1] is a module that has
;; an op with the attribute scale.
(import (except (chezscheme) =)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef) (mlir IR Operation)
        (mlir IR BuiltinTypes) (mlir IR BuiltinAttributes) (mlir IR Attributes) (mlir Support WalkResult))

(define (say label value) (display label) (display ": ") (display value) (newline))
(define (type-text type) (mlir::Attribute::print (mlir::TypeAttr::get type)))
(define (yes-no x) (if x "yes" "no"))
(define (parse-type text) (mlir::TypeAttr::getValue (mlir::parseAttribute text)))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (with-current-MLIRContext ctx
      (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
      (say "allows unregistered dialects" (yes-no (mlir::MLIRContext::allowsUnregisteredDialects? ctx)))
      (say "threads before" (yes-no (mlir::MLIRContext::isMultithreadingEnabled? ctx)))
      (mlir::MLIRContext::enableMultithreading ctx)
      (say "threads after enable" (yes-no (mlir::MLIRContext::isMultithreadingEnabled? ctx)))
      (mlir::MLIRContext::disableMultithreading ctx)
      (say "threads after disable" (yes-no (mlir::MLIRContext::isMultithreadingEnabled? ctx)))
      (mlir::MLIRContext::printOpOnDiagnostic ctx #f)
      (say "prints the op on a diagnostic" (yes-no (mlir::MLIRContext::shouldPrintOpOnDiagnostic? ctx)))
      (mlir::MLIRContext::printOpOnDiagnostic ctx #t)
      (say "prints the op on a diagnostic again" (yes-no (mlir::MLIRContext::shouldPrintOpOnDiagnostic? ctx)))
      (mlir::MLIRContext::printStackTraceOnDiagnostic ctx #f)
      (mlir::MLIRContext::loadAllAvailableDialects ctx)

      (say "f16" (type-text (mlir::Float16Type::get)))
      (say "bf16" (type-text (mlir::BFloat16Type::get)))
      (say "none" (type-text (mlir::NoneType::get)))
      (say "i1" (type-text (mlir::IntegerType::get<i1>)))
      (say "element type of complex<f32>" (type-text (mlir::ComplexType::getElementType (parse-type "complex<f32>"))))
      (say "element type of vector<4x2xi8>" (type-text (mlir::VectorType::getElementType (parse-type "vector<4x2xi8>"))))
      (say "rank of vector<4x2xi8>" (mlir::VectorType::getRank (parse-type "vector<4x2xi8>")))
      (say "memory space of memref<4xf32, 3>"
           (mlir::Attribute::print (mlir::MemRefType::getMemorySpace (parse-type "memref<4xf32, 3>"))))

      (let ([float (mlir::FloatAttr::get<f32> 1.5)]
            [string (mlir::StringAttr::get "text")])
        (say "float is a FloatAttr" (yes-no (mlir::isa<FloatAttr> float)))
        (say "string is a FloatAttr" (yes-no (mlir::isa<FloatAttr> string)))
        (say "string is a StringAttr" (yes-no (mlir::isa<StringAttr> string)))
        (say "float is a StringAttr" (yes-no (mlir::isa<StringAttr> float))))
      (say "flat symbol reference" (mlir::FlatSymbolRefAttr::getValue (mlir::FlatSymbolRefAttr::get "target")))

      (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car (command-line-arguments)))
        (let ([found 0])
          (mlir::Operation::walk module
                                 (lambda (op) (when (equal? (mlir::Operation::getName op) "t.op") (set! found op))
                                         #t mlir::WalkResult::advance))
          (say "float attribute of an op" (mlir::Operation::getAttrOfType<FloatAttr> found "scale")))))))
