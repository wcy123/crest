;; AST record types for define-dialect macro — imported at expand phase.
;; Separate library because define-record-type is phase-0; the transformer
;; runs at phase-1 and needs these accessible there.
(library (crest dialect ast)
  (export %%dialect-parse
          make-%%dialect-parse
          %%dialect-parse?
          %%dialect-parse-name
          %%dialect-parse-ops
          %%dialect-parse-cbs
          %%op-parse
          make-%%op-parse
          %%op-parse?
          %%op-parse-name
          %%op-parse-operands
          %%op-parse-attributes
          %%op-parse-results
          %%op-parse-op-cbs)
  (import (chezscheme))

  (define-record-type %%dialect-parse
    (fields (immutable name %%dialect-parse-name)
            (immutable ops  %%dialect-parse-ops)
            (immutable cbs  %%dialect-parse-cbs)))

  (define-record-type %%op-parse
    (fields (immutable name       %%op-parse-name)
            (immutable operands   %%op-parse-operands)
            (immutable attributes %%op-parse-attributes)
            (immutable results    %%op-parse-results)
            (immutable op-cbs     %%op-parse-op-cbs))))
