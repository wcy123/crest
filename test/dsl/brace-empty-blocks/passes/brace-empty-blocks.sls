#!chezscheme
;; Test: a block with no ops is made in its place, first, in the middle and last of its region,
;; and the blocks after it still start where they should. The conversion driver is used because
;; the greedy driver erases a block that no branch reaches.
(library (passes brace-empty-blocks)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir Transforms DialectConversion) with-TypeConverter)
          (crest))

  (define-conversion-pattern (%%empty_blocks op operands-ref rw tc)
    :if-match
      test.empty_blocks ()
    :rewrite op :with
      test.dst_empty_blocks ()
      { ^a ()
        ^b ()
        test.p () }
      { ^c ()
        test.q ()
        ^d ()
        ^e ()
        test.r () }
      { ^f ()
        test.s ()
        ^g () })

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-conversion module-op ctx
                          :partial-mode
                          :converter         (with-TypeConverter type-converter
                                               :conversions ((lambda (type) type)))
                          :legal-dialects    ("func" "builtin")
                          :illegal-dialects  ("test")
                          :legal-ops         ("test.dst_empty_blocks" "test.p" "test.q" "test.r" "test.s")
                          :patterns          (("test.empty_blocks" %%empty_blocks))))))

  ) ;; end library
