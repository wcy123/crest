;; Gets, removes and sets the argument attributes of an op through ArgAndResultAttrsOpInterface.
(import (only (mlir Support WalkResult) mlir::WalkResult::advance)
        (chezscheme)
        (crest dialect)
        (mlir IR Operation)
        (mlir IR MLIRContext)
        (mlir IR OwningOpRef)
        (mlir IR DialectRegistry)
        (only (mlir Interfaces CallInterfaces)
              mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr
              mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr
              mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr
              mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr))

(define (say . parts) (for-each display parts) (newline))

(define (main)
  ;; LEAK WARNING: what this makes (the context, the module, the builder) lives in a with- scope and is
  ;; freed when the scope ends. A raw MLIRContext::new, ModuleOp::create or parseSourceFile result that is
  ;; never freed leaked, and exit inside a scope skips the cleanup: raise, and exit at the top (%%quit).
  (let* ([args (command-line-arguments)])
    (with-DialectRegistry reg ()
      (with-MLIRContext ctx (reg)
        (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
        (load-scheme-dialect! ctx "aarattrs" "passes/aarattrs")
        (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car args))
          (when (zero? module)
            (display "Failed to parse\n" (current-error-port))
            (%%quit 1))
          (with-current-MLIRContext ctx
            (let ([ops '()])
              (mlir::Operation::walk
               module
               (lambda (op)
                 (when (equal? (mlir::Operation::getName op) "aarattrs.fn")
                   (set! ops (cons op ops)))
                 #t mlir::WalkResult::advance))
              (let* ([with (cadr ops)]
                     [without (car ops)]
                     [original (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr with)])
                (say "argument attributes: " (if (zero? original) 'none 'present))
                (say "result attributes: " (if (zero? (mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr with)) 'none 'present))
                (say "removed the same: " (if (= original (mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr with)) 'yes 'no))
                (say "after remove: " (if (zero? (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr with)) 'none 'present))
                (mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr with original)
                (say "after set: " (if (= original (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr with)) 'same 'different))
                (say "op without: " (if (zero? (mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr without)) 'none 'present))))))))))

;; A failure raises instead of calling exit: exit does not run the cleanup of the scopes around it.
(define (%%quit code)
  (raise (list 'exit code)))

(guard (e [(and (pair? e) (eq? (car e) 'exit)) (exit (cadr e))])
  (main))
