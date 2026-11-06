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
;;   :mode               partial | full                      default full
;;   :type-converter     a procedure (type) -> type or #f    added as a conversion callback, or
;;                       llvm                                an LLVMTypeConverter
;;   :legal-dialects     ("func" "builtin")                  names
;;   :illegal-dialects   ("toy")                             names
;;   :legal-ops          ("builtin.module")                  names
;;   :dynamically-legal  (("toy.print" (lambda (op) ...)))   (name predicate) entries
;;   :patterns           (("toy.add" %%add-lower!)           (name fn [benefit] [:no-type-converter])
;;                        ("toy.print" %%print-lower! :no-type-converter))
;;   :populate           (lambda (tc patterns) ...)          called with the converter and the
;;                                                           pattern set, after :patterns
;;
;; A pattern is registered with the type converter and benefit 1 unless the entry says
;; otherwise; :no-type-converter registers it so that it sees the original operand types.
;; Names, benefits and lambdas are ordinary expressions. The low-level API stays available.
;;
;;===----------------------------------------------------------------------===;;

(library (crest conversion)
  (export apply-conversion)
  (import (rnrs)
          (for (rnrs) expand)
          (for (only (chezscheme) syntax->list) expand)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Conversion LLVMCommon TypeConverter) with-LLVMTypeConverter)
          (only (mlir Transforms DialectConversion)
                with-TypeConverter
                with-ConversionTarget
                type-converter-add-conversion
                target-add-legal-dialect
                target-add-illegal-dialect
                target-add-legal-op
                target-add-dynamically-legal-op
                add-conversion-pattern
                add-conversion-pattern/ctx
                apply-full-conversion
                mlir::applyPartialConversion))

  (define-syntax apply-conversion
    (lambda (stx)
      (define known
        '(:mode :type-converter :legal-dialects :illegal-dialects :legal-ops
                :dynamically-legal :patterns :populate))

      (define (fail at message)
        (syntax-violation 'apply-conversion message at))

      ;; The elements of a proper list form, #f for anything else.
      (define (list-of x)
        (syntax-case x ()
          [(e ...) (syntax->list x)]
          [_ #f]))

      ;; (key value ...) -> alist of (key-symbol . value-syntax)
      (define (parse-options options)
        (let loop ([o options] [acc '()])
          (cond
           [(null? o) acc]
           [(null? (cdr o)) (fail (car o) "key without a value")]
           [else
            (let ([key (syntax->datum (car o))])
              (unless (memq key known) (fail (car o) "unknown key"))
              (when (assq key acc) (fail (car o) "repeated key"))
              (loop (cddr o) (cons (cons key (cadr o)) acc)))])))

      (define (lookup options key)
        (let ([entry (assq key options)])
          (and entry (cdr entry))))

      ;; The elements of a list value; an absent key is the empty list.
      (define (elements options key)
        (let ([value (lookup options key)])
          (cond
           [(not value) '()]
           [(list-of value) => (lambda (l) l)]
           [else (fail value (string-append (symbol->string key) " expects a list"))])))

      ;; (name fn [benefit] [:no-type-converter]) -> the registration form
      (define (pattern-form entry tc patterns)
        (let ([usage "a pattern is (name fn [benefit] [:no-type-converter])"]
              [parts (or (list-of entry) '())])
          (when (< (length parts) 2) (fail entry usage))
          (let* ([name   (car parts)]
                 [fn     (cadr parts)]
                 [tail   (cddr parts)]
                 [flag?  (and (pair? tail)
                              (eq? (syntax->datum (car (reverse tail))) ':no-type-converter))]
                 [tail   (if flag? (reverse (cdr (reverse tail))) tail)])
            (when (> (length tail) 1) (fail entry usage))
            (let ([benefit (if (null? tail) #'1 (car tail))])
              (if flag?
                  #`(add-conversion-pattern/ctx #,patterns #,name #,fn #,benefit)
                  #`(add-conversion-pattern #,patterns #,name #,fn #,tc #,benefit))))))

      (syntax-case stx ()
        [(_ module-op ctx option ...)
         (let* ([options (parse-options (syntax->list #'(option ...)))]
                [mode    (let ([m (lookup options ':mode)])
                           (cond
                            [(not m) 'full]
                            [(memq (syntax->datum m) '(partial full)) (syntax->datum m)]
                            [else (fail m ":mode is partial or full")]))]
                [tc-opt  (lookup options ':type-converter)]
                [llvm?   (and tc-opt (eq? (syntax->datum tc-opt) 'llvm))]
                [populate (lookup options ':populate)])
           (with-syntax ([(op* ctx* tc target patterns)
                          (generate-temporaries '(module-op ctx tc target patterns))])
             (with-syntax ([apply-fn (if (eq? mode 'partial)
                                         #'mlir::applyPartialConversion
                                         #'apply-full-conversion)]
                           [(conversion-form ...)
                            (if (and tc-opt (not llvm?))
                                (list #`(type-converter-add-conversion tc #,tc-opt))
                                '())]
                           [(legal-dialect-form ...)
                            (map (lambda (d) #`(target-add-legal-dialect target #,d))
                                 (elements options ':legal-dialects))]
                           [(illegal-dialect-form ...)
                            (map (lambda (d) #`(target-add-illegal-dialect target #,d))
                                 (elements options ':illegal-dialects))]
                           [(legal-op-form ...)
                            (map (lambda (n) #`(target-add-legal-op target ctx* #,n))
                                 (elements options ':legal-ops))]
                           [(dynamic-form ...)
                            (map (lambda (entry)
                                   (syntax-case entry ()
                                     [(name predicate)
                                      #`(target-add-dynamically-legal-op
                                         target ctx* name predicate)]
                                     [_ (fail entry
                                              "a dynamically legal entry is (name predicate)")]))
                                 (elements options ':dynamically-legal))]
                           [(pattern-form ...)
                            (map (lambda (e) (pattern-form e #'tc #'patterns))
                                 (elements options ':patterns))]
                           [(populate-form ...)
                            (if populate (list #`(#,populate tc patterns)) '())])
               (let ([body #'(with-ConversionTarget target (ctx*)
                               legal-dialect-form ...
                               illegal-dialect-form ...
                               legal-op-form ...
                               dynamic-form ...
                               (with-RewritePatternSet patterns (ctx*)
                                 pattern-form ...
                                 populate-form ...
                                 (eqv? 1 (apply-fn op* target patterns))))])
                 (if llvm?
                     #`(let ([op* module-op] [ctx* ctx])
                         (with-LLVMTypeConverter tc (ctx*) #,body))
                     #`(let ([op* module-op] [ctx* ctx])
                         (with-TypeConverter tc ()
                           conversion-form ...
                           #,body)))))))])))

  ) ;; end library (crest conversion)
