;; Shared utilities for expand-phase code generators.
(library (crest dialect expand utils)
  (export %%id %%id->str %%attr-names make-error-message)
  (import (chezscheme)
          (crest dialect ast)
          (crest pattern-dsl srcloc))

  ;; Build a syntax identifier from ctx + parts.
  ;; Parts may be strings, symbols, or syntax identifiers.
  (define (%%id ctx . parts)
    (datum->syntax ctx
                   (string->symbol
                    (apply string-append
                           (map (lambda (p)
                                  (cond
                                   [(string? p)     p]
                                   [(identifier? p) (symbol->string (syntax->datum p))]
                                   [(symbol? p)     (symbol->string p)]
                                   [else (error '%%id "expected string, identifier, or symbol" p)]))
                                parts)))))

  ;; Same conversion %%id uses internally: syntax identifier → string.
  (define (%%id->str stx) (symbol->string (syntax->datum stx)))

  ;; Extract attribute names as strings from a list of attribute-field records.
  (define (%%attr-names attrs)
    (map (lambda (f) (%%id->str (attribute-field-name f))) attrs))

  ;; Build an error message string from parts with the declaration site appended.
  ;; stx   — syntax object whose source location is appended; pass #f to omit.
  ;; parts — strings, symbols, or exact integers concatenated left-to-right.
  (define (make-error-message stx . parts)
    (with-output-to-string
      (lambda ()
        (let ([loc (and stx (syntax->file+line+col stx))])
          (when loc
            (display (car loc))  (display ":")
            (display (cadr loc)) (display ":")
            (display (caddr loc)) (display ": ")))
        (for-each display parts))))
  )
