;; Gets, removes and sets the argument attributes of an op through ArgAndResultAttrsOpInterface.
(import (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR MLIRContext)
        (only (mlir Interfaces CallInterfaces)
              mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
              mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr
              mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr
              mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr))

(define (say . parts) (for-each display parts) (newline))

(define (main)
  (let* ([args (command-line-arguments)]
         [ctx (mlir::MLIRContext::new)]
         [_   (mlir::MLIRContext::allowUnregisteredDialects ctx #t)]
         [_   (load-scheme-dialect! ctx "aarattrs" "passes/aarattrs")]
         [module (mlir::parseSourceFile ctx (car args))])
    (when (zero? module)
      (display "Failed to parse\n" (current-error-port))
      (exit 1))
    (with-current-MLIRContext ctx
      (let ([ops '()])
        (mlir::Operation::walk
         module
         (lambda (op)
           (when (equal? (mlir::Operation::getName op) "aarattrs.fn")
             (set! ops (cons op ops)))
           #t))
        (let* ([with (cadr ops)]
               [without (car ops)]
               [original (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr with)])
          (say "argument attributes: " (if (zero? original) 'none 'present))
          (say "result attributes: " (if (zero? (mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr with)) 'none 'present))
          (say "removed the same: " (if (= original (mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr with)) 'yes 'no))
          (say "after remove: " (if (zero? (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr with)) 'none 'present))
          (mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr with original)
          (say "after set: " (if (= original (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr with)) 'same 'different))
          (say "op without: " (if (zero? (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr without)) 'none 'present)))))))

(main)
