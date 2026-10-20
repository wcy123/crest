;; Shared utilities for expand-phase code generators.
(library (crest dialect expand utils)
  (export %%id %%id->str %%attr-names)
  (import (chezscheme)
          (crest dialect ast))

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
  )
