#!chezscheme
;; Test: a ^label inside { } starts a block, so one region has several blocks. The conversion
;; driver is used because the greedy driver erases a block that no branch reaches.
(library (passes brace-multi-block)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir Transforms DialectConversion) with-TypeConverter)
          (crest))

  ;; The first block has no label; a block runs from its label to the next label.
  (define-conversion-pattern (%%one_region_many_blocks op operands-ref rw tc)
    :if-match
      test.one_region_many_blocks ()
    :rewrite op :with
      test.dst_one_region_many_blocks ()
      { test.a ()
        test.a2 ()
        ^second ()
        test.b () })

  ;; Two regions, each with two blocks, and a nested op whose region has two blocks.
  (define-conversion-pattern (%%many_regions_many_blocks op operands-ref rw tc)
    :if-match
      test.many_regions_many_blocks ()
    :rewrite op :with
      test.dst_many_regions_many_blocks ()
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
  (define-conversion-pattern (%%same_as_old_region_form op operands-ref rw tc)
    :if-match
      test.same_as_old_region_form ()
    :rewrite op :with
      test.dst_same_as_old_region_form ()
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
                          :legal-ops         ("test.dst_one_region_many_blocks" "test.dst_many_regions_many_blocks" "test.dst_same_as_old_region_form"
                                              "test.a" "test.a2" "test.b" "test.c" "test.d"
                                              "test.e" "test.f" "test.g" "test.h" "test.inner")
                          :patterns          (("test.one_region_many_blocks" %%one_region_many_blocks)
                                              ("test.many_regions_many_blocks" %%many_regions_many_blocks)
                                              ("test.same_as_old_region_form" %%same_as_old_region_form))))))

  ) ;; end library
