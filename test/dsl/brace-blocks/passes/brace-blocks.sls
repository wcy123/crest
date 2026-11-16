#!chezscheme
;; Test: a ^label inside { } starts a block, so one region has several blocks. The conversion
;; driver is used because the greedy driver erases a block that no branch reaches.
(library (passes brace-blocks)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir Transforms DialectConversion) with-TypeConverter)
          (crest))

  ;; The first block has no label; a block runs from its label to the next label.
  (define-conversion-pattern (%%entry op operands-ref rw tc)
    :if-match
      test.entry ()
    :rewrite op :with
      test.dst_entry ()
      { test.a ()
        test.a2 ()
        ^second ()
        test.b () })

  ;; Two regions, each with two blocks, and a nested op whose region has two blocks.
  (define-conversion-pattern (%%regions op operands-ref rw tc)
    :if-match
      test.regions ()
    :rewrite op :with
      test.dst_regions ()
      { ^r0a ()
        test.c ()
        ^r0b ()
        test.inner ()
        { ^ia () test.d ()
          ^ib () test.e () }
        test.f () }
      { ^r1a ()
        test.g ()
        ^r1b ()
        test.h () })

  ;; The older (:region ...) form makes the same blocks.
  (define-conversion-pattern (%%old op operands-ref rw tc)
    :if-match
      test.old ()
    :rewrite op :with
      test.dst_old ()
      (:region (^first () test.a ())
               (^second () test.b ())))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-conversion module-op ctx
                          :partial-mode
                          :converter         (with-TypeConverter type-converter
                                               :conversions ((lambda (type) type)))
                          :legal-dialects    ("func" "builtin")
                          :illegal-dialects  ("test")
                          :legal-ops         ("test.dst_entry" "test.dst_regions" "test.dst_old"
                                              "test.a" "test.a2" "test.b" "test.c" "test.d"
                                              "test.e" "test.f" "test.g" "test.h" "test.inner")
                          :patterns          (("test.entry" %%entry)
                                              ("test.regions" %%regions)
                                              ("test.old" %%old))))))

  ) ;; end library
