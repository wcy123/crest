#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest patterns) — the apply-patterns and define-pattern-set macros.
;;
;;   (apply-patterns module-op ctx key value ...)
;;
;; Runs greedy rewrite patterns over module-op and returns #t on success, #f on failure. It makes
;; the RewritePatternSet, registers the patterns, applies them with applyPatternsGreedily and frees
;; the set. Every key is optional:
;;
;;   :patterns  (("toy.add" %%fn) ("toy.mul" %%fn 10))   (name pattern [benefit]); benefit defaults to 1
;;   :populate  (lambda (patterns) ...)                   a procedure of the pattern set, or a list of
;;                                                        them; called after :patterns
;;
;;   (define-pattern-set name (op-name pattern [benefit]) ...)
;;
;; defines the procedure name of a pattern set, which registers the patterns, so a library can keep
;; its table next to its patterns and a pass can say :populate name.
;;
;; Names, benefits and procedures are ordinary expressions. The low-level API stays available.
;;
;;===----------------------------------------------------------------------===;;

(library (crest patterns)
  (export apply-patterns define-pattern-set)
  (import (rnrs)
          (for (rnrs) expand)
          (for (only (chezscheme) syntax->list) expand)
          (for (crest patterns expand) expand)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern))

  ;; A :populate value is a procedure of the pattern set, or a list of them.
  (define (%%populate! populate patterns)
    (cond
     [(procedure? populate) (populate patterns)]
     [(list? populate) (for-each (lambda (p) (p patterns)) populate)]
     [else (error 'apply-patterns
                  ":populate expects a procedure or a list of procedures" populate)]))

  (define-syntax apply-patterns
    (lambda (stx)
      (define known '(:patterns :populate))

      (define (fail at message)
        (syntax-violation 'apply-patterns message at))

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

      (syntax-case stx ()
        [(_ module-op ctx option ...)
         (let* ([options  (parse-options (syntax->list #'(option ...)))]
                [patterns (lookup options ':patterns)]
                [populate (lookup options ':populate)]
                [entries  (cond
                           [(not patterns) '()]
                           [(list-of patterns) => (lambda (l) l)]
                           [else (fail patterns ":patterns expects a list")])])
           (with-syntax ([(op* ctx* set) (generate-temporaries '(module-op ctx patterns))])
             (with-syntax ([(pattern-option ...)
                            (if (null? entries)
                                '()
                                (list #':rewrite-patterns
                                      #`(#,@(map (lambda (e) (pattern-entry 'apply-patterns e))
                                                 entries))))]
                           [(populate-form ...)
                            (if populate (list #`(%%populate! #,populate set)) '())])
               #'(let ([op* module-op] [ctx* ctx])
                   (with-RewritePatternSet set (ctx* pattern-option ...)
                     populate-form ...
                     (eqv? 1 (mlir::applyPatternsGreedily op* set)))))))])))

  (define-syntax define-pattern-set
    (lambda (stx)
      (syntax-case stx ()
        [(_ name entry ...)
         (identifier? #'name)
         (with-syntax ([(set) (generate-temporaries '(patterns))])
           (with-syntax ([(pattern-form ...)
                          (map (lambda (e) (pattern-entry-form 'define-pattern-set e #'set))
                               (syntax->list #'(entry ...)))])
             #'(define (name set)
                 pattern-form ...
                 (if #f #f))))])))

  ) ;; end library (crest patterns)
