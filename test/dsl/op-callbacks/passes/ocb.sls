#!r6rs
;; A Scheme dialect whose ops have the callbacks that no other test uses: :verify-regions, a :verify
;; that fails or raises, :populate-default-attrs and folders that answer in place or wrongly.
(library (passes ocb)
  (export ocb)
  (import (except (rnrs) =)
          (mlir IR Value)
          (mlir IR Operation)
          (mlir IR BuiltinAttributes)
          (mlir IR MLIRContext)
          (crest dialect))

  (define (say . words)
    (let ([port (current-error-port)])
      (for-each (lambda (word) (display word port)) words)
      (newline port)
      (flush-output-port port)))

  (define-dialect ocb
    ;; :verify-regions runs after the verifier of the op and the verifiers of its regions.
    (define-op regions
      (:verify-regions (op) (say "verify-regions") #t))
    (define-op badregions
      (:verify-regions (op)
        (mlir::Operation::emitError op "the regions are not allowed")
        #f))
    (define-op verified
      (:verify (op) (say "verify") #t))
    (define-op bad
      (:verify (op)
        (mlir::Operation::emitError op "the op is not allowed")
        #f))
    (define-op raises
      (:verify (op) (error 'verify "the verifier is broken")))
    (define-op defaults
      (:populate-default-attrs (op-name attrs) (say "populate-default-attrs")))

    ;; A folder that answers a list with something that fold-value and fold-attribute did not make.
    (define-op malformed
      :results ((out mlir::Value?))
      (:fold (op operand-attributes) (list 'oops)))
    ;; A folder that answers two results for an op with one.
    (define-op toomany
      :results ((out mlir::Value?))
      (:fold (op operand-attributes)
        (with-current-MLIRContext (mlir::Operation::getContext op)
          (list (fold-attribute (mlir::IntegerAttr::get<i64> 1))
                (fold-attribute (mlir::IntegerAttr::get<i64> 2))))))
    ;; A folder that changes the op and answers '(): folded in place. It does so once.
    (define-op inplace
      :results ((out mlir::Value?))
      (:fold (op operand-attributes)
        (and (let ([done (mlir::Operation::getAttr op "done")]) (or (not done) (eqv? done 0)))
             (with-current-MLIRContext (mlir::Operation::getContext op)
               (mlir::Operation::setAttr! op "done" (mlir::UnitAttr::get))
               '()))))))
