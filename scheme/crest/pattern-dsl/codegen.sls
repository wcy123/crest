#!r6rs
(library (crest pattern-dsl codegen)
  (export generate-debug-ast
          generate-pattern-match-and-rewrite
          generate-debug-codegen
          make-unbound-value
          unbound-value?
          run-pipeline)
  (import (rnrs)
          (only (chezscheme) syntax->list syntax->datum syntax-object->datum record-rtd record-type-field-names record-accessor identifier?
                call-with-string-output-port display-condition)
          ;; match-logging: unified warning helper for generated debug code.
          (only (crest pattern-dsl match-logging) warn-match)
          ;; srcloc: shared source-location utilities; cache is module-level in srcloc.sls.
          (only (crest pattern-dsl srcloc) syntax->file+line+col)
          (rename (rime loop) (:with :rime-with))
          (for (only (chezscheme) syntax->list syntax->datum record-rtd record-type-field-names record-accessor identifier?
                     call-with-string-output-port write) expand)

          (for (rename (rime loop) (:with :rime-with)) expand)
          (for (crest pattern-dsl ast) expand)
          (for (crest pattern-dsl parse) expand)
          (for (crest pattern-dsl validate) expand)
          (for (crest pattern-dsl analyze) expand)
          (for (only (mlir support logging) crest::logging::warning) expand)
          (for (only (mlir IR PatternMatch)
                     mlir::RewriterBase::setInsertionPoint
                     mlir::RewriterBase::replaceOp) expand)
          (for (only (mlir IR Operation)
                     mlir::Operation::getContext
                     mlir::Operation::getNumResults
                     mlir::Operation::getResult
                     mlir::OpOperand::get
                     mlir::Operation::hasAttr?
                     mlir::Operation::getAttr
                     mlir::Operation::getName
                     mlir::Operation::emitError
                     operation-get-operands) expand)
          (for (only (mlir IR Value) mlir::Value::getDefiningOp) expand)
          (for (only (mlir support array-ref) ArrayRef::size ArrayRef::at with-CrestObject) expand)
          (for (only (mlir IR MLIRContext) current-MLIRContext) expand)
          (for (only (chezscheme) parameterize) expand)
          (for (only (crest pattern-dsl rewrite) begin-mlir-code) expand)
          ;; keywords needed at expand time for free-identifier=? matching in %%transform-where-expr
          (for (only (crest pattern-dsl keywords) :current-op :attr :has-attr? :attr-or) expand))

  ;;=======================================================================
  ;; Call graph
  ;;=======================================================================
  ;;
  ;; generate-pattern-match-and-rewrite
  ;; ├── %%generate-root-result-setters  (set! %varN (mlir::Operation::getResult op N)) per root result
  ;; │   └── %%find-root-op
  ;; ├── %%collect-all-variables
  ;; ├── %%generate-check-code           (and check₀ check₁ …) for :if-match
  ;; │   └── %%action->check-code
  ;; ├── %%generate-rewrite-code (raw-body)  wraps with-RewriterBase + begin-mlir-code
  ;; │   :rewrite :with body forwarded verbatim to begin-mlir-code; no AST round-trip
  ;; └── %%generate-then-let-bindings    ((var expr) …) for :then-let
  ;;
  ;; generate-debug-ast / generate-debug-codegen  (debug path, not on hot path)
  ;; └── %%record->alist
  ;;
  ;;=======================================================================
  ;; Entry points (called from pattern-macro.sls waterfall)
  ;;=======================================================================

  (define (generate-debug-ast ast-rec)
    (with-syntax ([fname (ast-pattern-expand-function-name ast-rec)])
      (let ([alist-data (%%record->alist ast-rec)])
        (with-syntax ([ast-list (datum->syntax #'fname `',alist-data)])
          #'(define fname (lambda () ast-list))))))

  (define (generate-debug-codegen ast-rec generated-code)
    (with-syntax ([fname (ast-pattern-expand-function-name ast-rec)])
      (let ([code-datum (syntax-object->datum generated-code)])
        (with-syntax ([code-list (datum->syntax #'fname `',code-datum)])
          #'(define fname (lambda () code-list))))))

  (define (generate-pattern-match-and-rewrite ast-rec)
    ;; All four are syntax identifiers from the user's call site (guaranteed by validation).
    ;; They become the lambda parameters in the generated function, so references to them
    ;; in :then-let expressions share the same binding via hygiene.
    (let* ([op             (ast-pattern-expand-param-op             ast-rec)] ; syntax-identifier
           [operands-ref   (ast-pattern-expand-param-operands-ref   ast-rec)] ; syntax-identifier
           [rewriter       (ast-pattern-expand-param-rewriter       ast-rec)] ; syntax-identifier
           [type-converter (ast-pattern-expand-param-type-converter ast-rec)]) ; syntax-identifier

      ;; Independent reads from the AST — no ordering required.
      (let* ([match-vec      (ast-pattern-expand-match          ast-rec)]
             [root-var-stx   (ast-pattern-expand-root-var       ast-rec)]
             [analysis       (ast-pattern-expand-match-analysis ast-rec)]
             [binding-mgr    (ast-match-analysis-bindings       analysis)]
             [actions        (ast-match-analysis-actions        analysis)]
             [pattern-type   (ast-pattern-expand-pattern-type   ast-rec)]
             [raw-rewrite    (ast-pattern-expand-rewrite         ast-rec)]
             [then-let-bindings (ast-pattern-expand-then-let    ast-rec)])

        ;; Computed values — each may depend on earlier bindings in this block.
        (let* ([num-ops          (vector-length match-vec)]
               [root-op             (%%find-root-op match-vec root-var-stx)]
               [root-result-vars    (ast-match-expand-result-var root-op)]
               [root-result-setters (%%generate-root-result-setters root-result-vars op)]
               ;; :rewrite :with body kept as raw syntax — forwarded to begin-mlir-code.
               ;; Rewrite vars are NOT pre-declared in the outer let; begin-mlir-code
               ;; declares them in its own let*.
               [match-vars       (%%collect-all-variables binding-mgr)]
               [then-let-vars    (map ast-then-let-binding-expand-var then-let-bindings)]
               [all-vars         (append match-vars then-let-vars)]
               )

          ;; Code generation — the two halves are independent of each other.
          (let ([check-code  (%%generate-check-code actions match-vec operands-ref
                                                    (ast-pattern-expand-debug-matching? ast-rec)
                                                    (ast-pattern-expand-function-name ast-rec))]
                [rewrite-code (%%generate-rewrite-code raw-rewrite pattern-type rewriter op)])

            ;; Build param list: 4 params for conversion, 2 for rewrite (no operands-ref/type-converter)
            (let ([params (if operands-ref
                              (list op operands-ref rewriter type-converter)
                              (list op rewriter))])
              (with-syntax ([fname    (ast-pattern-expand-function-name ast-rec)]
                            [(param ...) params]
                            [(var ...) all-vars]
                            [num-operations num-ops]
                            [(root-result-setter ...) root-result-setters]
                            [(then-let-binding ...) (%%generate-then-let-bindings then-let-bindings)]
                            [checks  check-code]
                            [rewrite rewrite-code])
                (with-syntax ([root-op op])
                  #'(define fname
                      (lambda (param ...)
                        ;; Install current-MLIRContext from the root op so that
                        ;; make-mlir-attribute and type constructors work in :then-let
                        ;; without requiring an explicit ctx argument.
                        (parameterize ([current-MLIRContext
                                        (mlir::Operation::getContext root-op)])
                          (let ([var (make-unbound-value)] ...
                                ;; 0 = unset; non-zero = valid Operation*.
                                [all-operations (make-vector num-operations 0)])
                            root-result-setter ...
                            (if checks
                                (let* (then-let-binding ...)
                                  rewrite)
                                #f)))))))))))))

  ;;=======================================================================
  ;; Rewrite code — thin wrapper delegating to begin-mlir-code
  ;;=======================================================================
  ;;
  ;; %%generate-rewrite-code
  ;;
  ;; raw-body     — list of raw syntax objects (the :rewrite :with op-forms)
  ;; pattern-type — 'conversion | 'rewrite
  ;; rw / op      — syntax identifiers for the rewriter and matched operation
  ;;
  ;; Generated shape ('conversion):
  ;;   (with-RewriterBase (rw op)
  ;;     (let ([result (begin-mlir-code form ...)])
  ;;       (mlir::RewriterBase::replaceOp rw op result)
  ;;       #t))
  ;;
  ;; begin-mlir-code handles op-forms, :attrs, :regions, and :scheme escapes.
  ;; with-RewriterBase calls setInsertionPoint so
  ;; dispatches through the active rewriter or block-builder.
  (define (%%generate-rewrite-code raw-body pattern-type rw op)
    (if (null? raw-body)
        #'#t
        (with-syntax ([(form ...) raw-body])
          (case pattern-type
            [(conversion rewrite)
             ;; rwShell is owned by C++ (unique_ptr); no with-CrestObject needed.
             #`(guard (exn [#t
                            ;; A Scheme exception in the rewrite body is a pattern
                            ;; failure. Emit the full condition text as an MLIR
                            ;; diagnostic so it appears in ORT's error output.
                            (mlir::Operation::emitError #,op
                                                        (call-with-string-output-port
                                                         (lambda (p) (display-condition exn p))))
                            #f])
                 (begin
                   (mlir::RewriterBase::setInsertionPoint #,rw #,op)
                   (let ([result (begin-mlir-code #,rw form ...)])
                     ;; result is a Value* uptr on success, or #f to signal failure.
                     (if result
                         (begin (mlir::RewriterBase::replaceOp #,rw #,op result) #t)
                         #f))))]))))

  ;;=======================================================================
  ;; :then-let bindings
  ;;=======================================================================

  (define (%%generate-then-let-bindings then-let-list)
    (loop :for binding-rec :in then-let-list
          :rime-with var  := (ast-then-let-binding-expand-var  binding-rec)
          :rime-with expr := (ast-then-let-binding-expand-expr binding-rec)
          :collect (list var expr)))

  ;;=======================================================================
  ;; Match-phase check code
  ;;=======================================================================

  ;;=======================================================================
  ;; :where expression transformation — :current-op and (:attr ...) keywords
  ;;=======================================================================
  ;;
  ;; Called at macro-expansion time before emitting each :where guard.
  ;; Walks the where-expression syntax and substitutes:
  ;;   :current-op    → (vector-ref all-operations op-idx)
  ;;                    the sub-op being matched (not the root op that `op` refers to)
  ;;   (:attr "name") → fetch named attribute from :current-op as raw uptr;
  ;;                    raise (error ...) if absent → guard returns #f
  ;;
  ;; Compose (:attr "name") with explicit builtin-attributes extractors, e.g.:
  ;;   (mlir::IntegerAttr::getValue  (:attr "axis"))
  ;;   (mlir::FloatAttr::getValueAsDouble.f32  (:attr "epsilon"))
  ;;   (mlir::DenseElementsAttr::isSplat (:attr "value"))
  ;;
  ;; Uses free-identifier=? via (syntax-case s (:current-op :attr) ...) so
  ;; only :current-op/:attr from (crest pattern-dsl keywords) are substituted.

  ;; %%transform-where-expr — syntactic substitution for :where expressions.
  ;;
  ;; No (:attr "name" :type) form: clients compose (:attr "name") with
  ;; explicit attr-extraction functions from (mlir IR BuiltinAttributes).
  (define (%%transform-where-expr where-stx op-idx)
    (let ([cur-op #`(vector-ref all-operations #,op-idx)])
      (let walk ([s where-stx])
        (syntax-case s (:current-op :attr :has-attr? :attr-or)
          ;; Bare :current-op identifier → the matched sub-op
          [:current-op cur-op]
          ;; (:has-attr? "name") → #t/#f. hasAttr? wraps int with (= 1 ...) → boolean.
          [(:has-attr? name)
           (string? (syntax->datum #'name))
           #`(mlir::Operation::hasAttr? #,cur-op name)]
          ;; (:attr-or "name" default) → attr value if present, else default — no error
          [(:attr-or name default)
           (string? (syntax->datum #'name))
           #`(let ([%cur #,cur-op])
               (if (mlir::Operation::hasAttr? %cur name)
                   (mlir::Operation::getAttr %cur name)
                   default))]
          ;; (:attr "name") → raw attr uptr, or #f if absent (clean match failure).
          ;; hasAttr? wraps int with (= 1 ...) → proper #t/#f boolean; safe in if.
          [(:attr name)
           (string? (syntax->datum #'name))
           #`(let ([%cur #,cur-op])
               (if (mlir::Operation::hasAttr? %cur name)
                   (mlir::Operation::getAttr %cur name)
                   #f))]
          ;; Recurse into compound forms
          [(e ...) #`(#,@(map walk (syntax->list s)))]
          ;; Atoms pass through unchanged
          [_ s]))))

  ;; Extract the most informative source syntax object from an action,
  ;; used to compute file:line:col for debug-match diagnostics.
  ;; op-name is (normalized-string . original-stx) after validation — use cdr for location.
  (define (%%action->source-stx action match-vec)
    (let ([tag (car action)] [fields (cdr action)])
      (case tag
        [(:check-op)
         ;; op-name is now a plain string; use the first result-var for source location.
         (let ([match-op (vector-ref match-vec (cdr (assq 'op-idx fields)))])
           (car (ast-match-expand-result-var match-op)))]
        [(:check-where)
         (cdr (assq 'expr fields))]
        [(:bind-argument-operand :bind-result)
         (cdr (assq 'var fields))]
        [(:bind-operands)
         (let ([vars (cdr (assq 'vars fields))])
           (and (pair? vars) (car vars)))]
        [else #f])))

  ;;=======================================================================
  ;; CREST_DEBUG_MATCH warning format (stable contract)
  ;;=======================================================================
  ;;
  ;; Check failure (CREST_DEBUG_MATCH=1):
  ;;   [warning] <file>:<line>:<col>: [<pattern>] FAILED: <scheme-expr>
  ;;   [warning]   actual: <mlir-op-text>        ; only for :check-op
  ;;
  ;; Unexpected exception (always emitted, regardless of CREST_DEBUG_MATCH):
  ;;   [warning] unknown: [<pattern>] exception: <condition-message>
  ;;
  ;; <pattern> is the Scheme function name of the define-rewrite-pattern.
  ;; <file>:<line>:<col> points to the failing op in the pattern .sls source.
  ;;=======================================================================
  (define (%%generate-check-code actions match-vec operands-ref debug? fname-stx)
    ;; Exceptions during matching are always unexpected — always log them.
    ;; debug? only controls per-check FAILED: messages for normal #f returns.
    (define fname-sym (symbol->string (syntax->datum fname-stx)))
    ;; Format (list file line col) | #f → "file:line:col" | "unknown"
    (define (loc->string loc)
      (if loc
          (apply (lambda (file line col)
                   (string-append file ":" (number->string line)
                                  ":" (number->string col)))
                 loc)
          "unknown"))
    ;; For :check-op, generate a runtime expression for the actual op so we
    ;; can print its name alongside the FAILED: message.
    (define (%%action->actual-op-stx action)
      ;; :current-op is (vector-ref all-operations op-idx) for any action with
      ;; op-idx. :set-current-op always writes to the slot (def-op or 0) so
      ;; warn-match safely sees 0 and skips actual: when def-op is null.
      (let ([op-idx-cell (assq 'op-idx (cdr action))])
        (and op-idx-cell
             #`(vector-ref all-operations #,(cdr op-idx-cell)))))
    ;; Every check is wrapped in a per-check guard so exceptions carry
    ;; file:line:col of the specific check that threw — not "unknown:".
    ;; Exception logging is always-on; FAILED: logging is debug? only.
    (define (make-check-form chk src-stx actual-op-stx action-tag)
      (let* ([loc       (and src-stx (syntax->file+line+col src-stx))]
             [loc-str   (loc->string loc)]
             [tag-str   (symbol->string action-tag)]
             [ex-prefix (string-append loc-str ": [" fname-sym "] " tag-str " exception: ")]
             ;; body-of-checks: (or check (warn "FAILED:" actual)) in debug,
             ;; plain check in production.
             [body-of-checks
              ;; :set-current-op failure (no defining op) is a silent structural
              ;; mismatch — not actionable on its own. The following :check-op
              ;; will provide the meaningful FAILED: message if needed.
              (if (and debug? (not (eq? action-tag ':set-current-op)))
                  (let ([fmsg (string-append
                               loc-str ": [" fname-sym "] " tag-str " FAILED: "
                               (call-with-string-output-port
                                (lambda (p) (write (syntax->datum chk) p))))])
                    (with-syntax ([check chk]
                                  [fmsg  (datum->syntax #'quote fmsg)]
                                  [op    (or actual-op-stx #'0)])
                      #'(or check (begin (warn-match fmsg op) #f))))
                  chk)])
        (with-syntax ([body-of-checks body-of-checks]
                      [exprefix       (datum->syntax #'quote ex-prefix)]
                      [op             (or actual-op-stx #'0)])
          #'(guard (exn [#t
                         (warn-match (string-append exprefix
                                                    (call-with-string-output-port
                                                     (lambda (p) (display-condition exn p))))
                                     op)
                         #f])
              body-of-checks))))
    (define (%%make-checks)
      ;; Always wrap each check in a per-check guard (always-on exception loc).
      (let* ([raw-checks  (map (lambda (act) (%%action->check-code act match-vec operands-ref)) actions)]
             [src-stxs    (map (lambda (act) (%%action->source-stx act match-vec)) actions)]
             [actual-stxs (map %%action->actual-op-stx actions)]
             [tags        (map car actions)])
        (map make-check-form raw-checks src-stxs actual-stxs tags)))
    (if (null? actions)
        #'#t
        (with-syntax ([(check-form ...) (%%make-checks)])
          #'(and check-form ...))))

  (define (%%action->check-code action match-vec operands-ref)
    (let ([tag (car action)])
      (case tag
        [(:set-current-op)
         (let* ([fields (cdr action)]
                [op-idx (cdr (assq 'op-idx fields))]
                [var    (cdr (assq 'var fields))])
           #`(let ([def-op (mlir::Value::getDefiningOp #,var)])
               ;; Slot initialized to 0; non-zero means already visited — bug
               ;; in the analyze phase. Caught by the per-check guard which
               ;; logs it as an unexpected exception with location and actual:.
               (when (not (zero? (vector-ref all-operations #,op-idx)))
                 (error ':set-current-op
                        "analyze-phase bug: op slot already set"
                        #,op-idx))
               ;; :set-current-op is pure setup, not a constraint.
               ;; Write 0 for a null def-op; :check-op is the gatekeeper.
               (vector-set! all-operations #,op-idx (or def-op 0))
               #t))]

        [(:check-op)
         (let* ([fields      (cdr action)]
                [op-idx      (cdr (assq 'op-idx fields))]
                [match-op    (vector-ref match-vec op-idx)]
                [op-name     (ast-match-expand-op-name match-op)]
                [num-results (length (ast-match-expand-result-var match-op))])
           #`(and (string=? (mlir::Operation::getName (vector-ref all-operations #,op-idx))
                            #,op-name)
                  (= (mlir::Operation::getNumResults (vector-ref all-operations #,op-idx))
                     #,num-results)))]

        [(:bind-argument-operand)
         (let* ([fields      (cdr action)]
                [var         (cdr (assq 'var fields))]
                [operand-idx (cdr (assq 'operand-idx fields))])
           #`(if (< #,operand-idx (ArrayRef::size #,operands-ref))
                 (let ([val (ArrayRef::at #,operands-ref #,operand-idx)])
                   (and (not (zero? val))
                        (begin (set! #,var val) #t)))
                 #f))]

        [(:bind-result)
         ;; Set a non-root result variable to the actual mlir::Value so that
         ;; :where guards and :then-let can reference it by name.
         (let* ([fields     (cdr action)]
                [op-idx     (cdr (assq 'op-idx     fields))]
                [result-idx (cdr (assq 'result-idx fields))]
                [var        (cdr (assq 'var        fields))])
           #`(begin
               (set! #,var (mlir::Operation::getResult
                            (vector-ref all-operations #,op-idx)
                            #,result-idx))
               #t))]

        [(:check-where)
         ;; Transform the where expression to substitute :current-op and (:attr ...)
         ;; before emitting.  op-idx is the index of the op this :where belongs to.
         (let* ([fields  (cdr action)]
                [op-idx  (cdr (assq 'op-idx fields))]
                [expr    (cdr (assq 'expr   fields))])
           (%%transform-where-expr expr op-idx))]

        [(:bind-operands)
         ;; Bind all operands via operation-get-operands, which returns #f on structural
         ;; mismatch (count wrong, or missing operandSegmentSizes for flex ops).
         (let* ([fields  (cdr action)]
                [op-idx  (cdr (assq 'op-idx fields))]
                [spec    (cdr (assq 'spec   fields))]
                [vars    (cdr (assq 'vars   fields))])
           (with-syntax ([%operands  (datum->syntax #'begin '%operands)]
                         [(quoted-spec ...)
                          (map (lambda (s)
                                 (with-syntax ([sym s]) #'(quote sym)))
                               spec)]
                         [(setting-or-comparing ...)
                          (loop :for var :in vars
                                :for i   :from 0
                                :collect (with-syntax ([v   var]
                                                       [idx (datum->syntax var i)])
                                           #'(if (unbound-value? v)
                                                 (begin (set! v (list-ref %operands idx)) #t)
                                                 (eqv? v (list-ref %operands idx)))))]
                         [op-idx* (datum->syntax #'begin op-idx)])
             #'(let ([%operands (operation-get-operands
                                 (vector-ref all-operations op-idx*)
                                 quoted-spec ...)])
                 (and %operands setting-or-comparing ...))))]

        [else
         (error '%%action->check-code "Unknown action type" tag)])))

  ;;=======================================================================
  ;; Root op lookup and initialization
  ;;=======================================================================

  (define (%%find-root-op match-vec root-var)
    ;; Find the match-op whose result list contains root-var.
    ;; Identity search — unambiguous even when multiple ops share the same name.
    (loop :initially := #f
          :for idx :from 0 :below (vector-length match-vec)
          :rime-with match-op := (vector-ref match-vec idx)
          :break match-op :if (loop :initially := #f
                                    :for var :in (ast-match-expand-result-var match-op)
                                    :when (bound-identifier=? var root-var)
                                    :break #t)))

  (define (%%generate-root-result-setters root-result-vars op-param)
    (loop :for var :in root-result-vars
          :for idx :from 0
          :collect #`(set! #,var (mlir::Operation::getResult #,op-param #,idx))))

  ;;=======================================================================
  ;; Variable collection
  ;;=======================================================================

  (define (%%collect-all-variables binding-mgr)
    (vector->list (hashtable-keys (binding-manager-bindings binding-mgr))))

  ;;=======================================================================
  ;; Leaf utilities
  ;;=======================================================================

  (define (make-unbound-value) (if #f #f))

  ;; Returns #t when v is an unbound pattern variable (i.e. an optional operand
  ;; that was absent at match time).  Clients use this in :then-let to check
  ;; whether an (:optional %var) was actually bound.
  (define (unbound-value? v) (eq? v (make-unbound-value)))

  (define (%%record->alist obj)
    (let ([datum (syntax-object->datum obj)])
      (cond
       [(not (eq? datum obj)) datum]
       [(hashtable? obj)
        (let* ([keys (vector->list (hashtable-keys obj))]
               [sorted-keys (list-sort (lambda (a b)
                                         (string<? (if (identifier? a)
                                                       (symbol->string (syntax->datum a))
                                                       (symbol->string a))
                                                   (if (identifier? b)
                                                       (symbol->string (syntax->datum b))
                                                       (symbol->string b))))
                                       keys)])
          (loop :for key :in sorted-keys
                :collect (cons (%%record->alist key)
                               (%%record->alist (hashtable-ref obj key #f)))))]
       [(record? obj)
        (let* ([rtd (record-rtd obj)]
               [field-names (vector->list (record-type-field-names rtd))])
          (loop :for name :in field-names
                :for i :from 0
                :collect (let* ([accessor (record-accessor rtd i)]
                                [value (accessor obj)])
                           (cons name (%%record->alist value)))))]
       [(list? obj) (map %%record->alist obj)]
       [(vector? obj) (vector->list (vector-map %%record->alist obj))]
       [else obj])))

  ;; Shared pipeline helper — runs the 4 phases, short-circuits on debug flags.
  ;; Defined here so crest.sls can call it from define-syntax transformers
  ;; (codegen is already imported (for ... expand) there).
  (define (run-pipeline stx type)
    (let ([ast-rec (parse-to-ast stx type)])
      (if (ast-pattern-expand-debug-parse? ast-rec)
          (generate-debug-ast ast-rec)
          (let ([validated (validate-ast ast-rec)])
            (if (ast-pattern-expand-debug-validate? validated)
                (generate-debug-ast validated)
                (let ([analyzed (analyze-ast validated)])
                  (if (ast-pattern-expand-debug-analyze? analyzed)
                      (generate-debug-ast analyzed)
                      (let ([real-code (generate-pattern-match-and-rewrite analyzed)])
                        (if (ast-pattern-expand-debug-codegen? analyzed)
                            (generate-debug-codegen analyzed real-code)
                            real-code)))))))))

  )
