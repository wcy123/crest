#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest conversion) — the apply-conversion macro.
;;
;;   (apply-conversion module-op ctx key value ...)
;;
;; Runs a dialect conversion over module-op and returns #t on success, #f on failure. It makes
;; the TypeConverter, the ConversionTarget and the RewritePatternSet, fills them from the keys,
;; applies the conversion and frees them, in that order, so a pass states what it converts and
;; not how the objects are created and freed. Every key is optional:
;;
;;   :partial-mode       a flag without a value: a partial conversion
;;   :full-mode          a flag without a value: a full conversion (the default)
;;   :converter          (with-TypeConverter converter :conversions (...))
;;                       (with-LLVMTypeConverter converter (ctx))
;;                                                           the macro that makes the converter, without
;;                                                           its body: the pass writes the variable and
;;                                                           the arguments, apply-conversion adds the body
;;   :legal-dialects     ("func" "builtin")                  names
;;   :illegal-dialects   ("toy")                             names
;;   :legal-ops          ("builtin.module")                  names
;;   :dynamically-legal  (("toy.print" (lambda (op) ...)))   (name predicate) entries
;;   :patterns           (("toy.add" %%add-lower!)           (name fn [benefit] [:no-type-converter])
;;                        ("toy.print" %%print-lower! :no-type-converter))
;;   :populate           (lambda (converter patterns) ...)   called with the converter and the
;;                                                           pattern set, after :patterns
;;   :configure-type-converter  a procedure (converter)      called with the converter, first thing in
;;                                                           the body of :converter
;;   :configure-target  a procedure (target converter)       called with the target and the converter,
;;                                                           after the legal/illegal keys
;;
;; Without :converter the converter is a plain TypeConverter with no conversions. The variable of
;; :converter is bound in the whole conversion, so a pass can use it in :patterns, :populate and so on.
;;
;; A pattern is registered with the type converter and benefit 1 unless the entry says
;; otherwise; :no-type-converter registers it so that it sees the original operand types.
;; Names, benefits and lambdas are ordinary expressions. The low-level API stays available.
;;
;;===----------------------------------------------------------------------===;;

(library (crest conversion)
  (export apply-conversion
          :partial-mode :full-mode
          :converter :legal-dialects :illegal-dialects :legal-ops
          :dynamically-legal :patterns :populate
          :configure-type-converter :configure-target :no-type-converter)
  (import (rnrs)
          (for (rnrs) expand)
          (for (only (chezscheme) syntax->list) expand)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms DialectConversion)
                with-TypeConverter
                with-ConversionTarget
                target-add-legal-dialect
                target-add-illegal-dialect
                target-add-legal-op
                apply-full-conversion
                mlir::applyPartialConversion))

  ;; The words of apply-conversion are bound, so that a use matches them as literals by binding, not by name.
  (define-syntax define-keywords
    (lambda (stx)
      (syntax-case stx ()
        [(_ name ...)
         #'(begin
             (define-syntax name
               (lambda (use) (syntax-violation 'apply-conversion "misplaced keyword of apply-conversion" use)))
             ...)])))

  (define-keywords :partial-mode :full-mode
    :converter :legal-dialects :illegal-dialects :legal-ops
    :dynamically-legal :patterns :populate
    :configure-type-converter :configure-target :no-type-converter)

  (define-syntax apply-conversion
    (lambda (stx)
      (define (fail at message)
        (syntax-violation 'apply-conversion message at))

      (syntax-case stx ()
        [(_ module-op ctx option ...)
         (with-syntax ([(op* ctx* converter target patterns)
                        (generate-temporaries '(module-op ctx converter target patterns))])
           (let ([seen '()]               ; the keys given so far
                 [mode 'full]
                 [converter-maker #'(with-TypeConverter converter)]   ; (maker variable argument ...), :converter replaces it
                 [slots '()])             ; (slot . forms), newest first: the forms that each key adds
             (define (emit! slot forms)
               (set! slots (cons (cons slot forms) slots)))
             (define (forms-of slot)
               (apply append (map cdr (filter (lambda (entry) (eq? (car entry) slot)) (reverse slots)))))

             ;; (name predicate)
             (define (check-dynamically-legal entry)
               (syntax-case entry ()
                 [(name predicate) entry]
                 [_ (fail entry "a dynamically legal entry is (name predicate)")]))

             ;; (name fn [benefit] [:no-type-converter]): registered with the converter unless the entry says otherwise
             (define (emit-pattern! entry)
               (syntax-case entry (:no-type-converter)
                 [(name fn :no-type-converter)         (emit! 'pattern/ctx (list #'(name fn 1)))]
                 [(name fn benefit :no-type-converter) (emit! 'pattern/ctx (list #'(name fn benefit)))]
                 [(name fn benefit)                    (emit! 'pattern (list #'(name fn converter benefit)))]
                 [(name fn)                            (emit! 'pattern (list #'(name fn converter 1)))]
                 [_ (fail entry "a pattern is (name fn [benefit] [:no-type-converter])")]))

             (define (assemble)
               (with-syntax ([apply-fn (if (eq? mode 'partial)
                                           #'mlir::applyPartialConversion
                                           #'apply-full-conversion)]
                             [(target-clause ...) (cons #'ctx* (forms-of 'target-clause))]
                             [(legal-dialect-form ...) (forms-of 'legal-dialect)]
                             [(illegal-dialect-form ...) (forms-of 'illegal-dialect)]
                             [(legal-op-form ...) (forms-of 'legal-op)]
                             [(configure-target-form ...) (forms-of 'configure-target)]
                             [(pattern-clause ...)
                              (append (if (null? (forms-of 'pattern))
                                          '()
                                          (list #':conversion-patterns #`(#,@(forms-of 'pattern))))
                                      (if (null? (forms-of 'pattern/ctx))
                                          '()
                                          (list #':conversion-patterns/ctx #`(#,@(forms-of 'pattern/ctx)))))]
                             [(populate-form ...) (forms-of 'populate)]
                             [(configure-converter-form ...) (forms-of 'configure-converter)])
                 (let ([body #'(with-ConversionTarget target (target-clause ...)
                                 legal-dialect-form ...
                                 illegal-dialect-form ...
                                 legal-op-form ...
                                 configure-target-form ...
                                 (with-RewritePatternSet patterns (ctx* pattern-clause ...)
                                   populate-form ...
                                   (eqv? 1 (apply-fn op* target patterns))))])
                   (syntax-case converter-maker ()
                     [(maker variable argument ...)
                      #`(let ([op* module-op] [ctx* ctx])
                          (maker variable argument ...
                                 (let ([converter variable])
                                   configure-converter-form ...
                                   #,body)))]))))

             (let loop ([rest #'(option ...)])
               (define (once! key . message)
                 (when (memq key seen)
                   (fail (car (syntax->list rest)) (if (null? message) "repeated key" (car message))))
                 (set! seen (cons key seen)))
               (syntax-case rest (:partial-mode :full-mode
                                                :converter :legal-dialects :illegal-dialects :legal-ops
                                                :dynamically-legal :patterns :populate
                                                :configure-type-converter :configure-target)
                 [() (assemble)]

                 [(:partial-mode . more)
                  (begin (once! 'mode "the mode is given once: :partial-mode or :full-mode")
                         (set! mode 'partial)
                         (loop #'more))]
                 [(:full-mode . more)
                  (begin (once! 'mode "the mode is given once: :partial-mode or :full-mode")
                         (set! mode 'full)
                         (loop #'more))]

                 [(key) (fail #'key "key without a value")]

                 [(:converter (maker variable argument ...) . more)
                  (and (identifier? #'maker) (identifier? #'variable))
                  (begin (once! ':converter)
                         (set! converter-maker #'(maker variable argument ...))
                         (loop #'more))]
                 [(:converter value . _)
                  (fail #'value ":converter is (with-<Class> variable argument ...), such as (with-TypeConverter converter :conversions (...))")]

                 [(:legal-dialects (name ...) . more)
                  (begin (once! ':legal-dialects)
                         (emit! 'legal-dialect
                                (map (lambda (name) #`(target-add-legal-dialect target #,name))
                                     (syntax->list #'(name ...))))
                         (loop #'more))]
                 [(:legal-dialects value . _) (fail #'value ":legal-dialects expects a list")]

                 [(:illegal-dialects (name ...) . more)
                  (begin (once! ':illegal-dialects)
                         (emit! 'illegal-dialect
                                (map (lambda (name) #`(target-add-illegal-dialect target #,name))
                                     (syntax->list #'(name ...))))
                         (loop #'more))]
                 [(:illegal-dialects value . _) (fail #'value ":illegal-dialects expects a list")]

                 [(:legal-ops (name ...) . more)
                  (begin (once! ':legal-ops)
                         (emit! 'legal-op
                                (map (lambda (name) #`(target-add-legal-op target ctx* #,name))
                                     (syntax->list #'(name ...))))
                         (loop #'more))]
                 [(:legal-ops value . _) (fail #'value ":legal-ops expects a list")]

                 [(:dynamically-legal (entry ...) . more)
                  (begin (once! ':dynamically-legal)
                         (emit! 'target-clause
                                (list #':dynamically-legal
                                      #`(#,@(map check-dynamically-legal (syntax->list #'(entry ...))))))
                         (loop #'more))]
                 [(:dynamically-legal value . _) (fail #'value ":dynamically-legal expects a list")]

                 [(:patterns (entry ...) . more)
                  (begin (once! ':patterns)
                         (for-each emit-pattern! (syntax->list #'(entry ...)))
                         (loop #'more))]
                 [(:patterns value . _) (fail #'value ":patterns expects a list")]

                 [(:populate procedure . more)
                  (begin (once! ':populate)
                         (emit! 'populate (list #'(procedure converter patterns)))
                         (loop #'more))]
                 [(:configure-type-converter procedure . more)
                  (begin (once! ':configure-type-converter)
                         (emit! 'configure-converter (list #'(procedure converter)))
                         (loop #'more))]
                 [(:configure-target procedure . more)
                  (begin (once! ':configure-target)
                         (emit! 'configure-target (list #'(procedure target converter)))
                         (loop #'more))]

                 [(key . _) (fail #'key "unknown key")]))))])))

  ) ;; end library (crest conversion)
