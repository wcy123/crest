#!r6rs
(library (crest internal codegen)
  (export generate-debug-ast
          generate-pattern-match-and-rewrite
          generate-debug-codegen
          make-unbound-value
          unbound-value?
          run-pipeline)
  (import (rnrs)
          (only (chezscheme) syntax->list syntax->datum syntax-object->datum record-rtd record-type-field-names record-accessor identifier?
                call-with-string-output-port display-condition)
          (rename (rime loop) (:with :rime-with))
          (for (only (chezscheme) syntax->list syntax->datum record-rtd record-type-field-names record-accessor identifier?) expand)
          (for (rename (rime loop) (:with :rime-with)) expand)
          (for (crest internal ast) expand)
          (for (crest internal parse) expand)
          (for (crest internal validate) expand)
          (for (crest internal analyze) expand)
          (for (only (mlir IR PatternMatch)
                     with-RewriterBase mlir::RewriterBase::replaceOp) expand)
          (for (rename (only (mlir IR Operation)
                             mlir::Operation::getContext
                             mlir::Operation::getNumResults
                             mlir::Operation::getResult
                             mlir::OpOperand::get
                             mlir::Operation::hasAttr?
                             mlir::Operation::getAttr
                             mlir::Operation::getName
                             mlir::Operation::emitError
                             operation-get-operands)
                       (mlir::Operation::getContext    mlir-Operation::getContext)
                       (mlir::Operation::getNumResults mlir-operation-num-results)
                       (mlir::Operation::getResult     mlir-Operation::getResult)
                       (mlir::OpOperand::get     mlir-operation-get-operand-value)
                       (mlir::Operation::hasAttr?      mlir-Operation::hasAttr?)
                       (mlir::Operation::getAttr       mlir-operation-get-attr)
                       (mlir::Operation::getName       mlir-operation-name)
                       (mlir::Operation::emitError    mlir-emit-error!)
                       (operation-get-operands   mlir-operation-get-operands)) expand)
          (for (rename (only (mlir IR Value) mlir::Value::getDefiningOp)
                       (mlir::Value::getDefiningOp mlir-value-get-defining-op)) expand)
          (for (only (mlir support array-ref) array-ref-size array-ref-at) expand)
          (for (only (mlir IR MLIRContext) current-MLIRContext) expand)
          (for (only (chezscheme) parameterize) expand)
          (for (only (crest internal rewrite) with-mlir-ops) expand)
          ;; keywords needed at expand time for free-identifier=? matching in transform-where-expr
          (for (only (crest internal keywords) :current-op :attr) expand))

  ;;=======================================================================
  ;; Call graph
  ;;=======================================================================
  ;;
  ;; generate-pattern-match-and-rewrite
  ;; ├── generate-root-result-setters  (set! %varN (mlir-Operation::getResult op N)) per root result
  ;; │   └── find-root-op
  ;; ├── collect-all-variables
  ;; ├── generate-check-code           (and check₀ check₁ …) for :if-match
  ;; │   └── action->check-code
  ;; ├── generate-rewrite-code (raw-body)  wraps with-RewriterBase + with-mlir-ops
  ;; │   :rewrite :with body forwarded verbatim to with-mlir-ops; no AST round-trip
  ;; └── generate-then-let-bindings    ((var expr) …) for :then-let
  ;;
  ;; generate-debug-ast / generate-debug-codegen  (debug path, not on hot path)
  ;; └── record->alist
  ;;
  ;;=======================================================================
  ;; Entry points (called from pattern-macro.sls waterfall)
  ;;=======================================================================

  (define (generate-debug-ast ast-rec)
    (with-syntax ([fname (ast-pattern-expand-function-name ast-rec)])
      (let ([alist-data (record->alist ast-rec)])
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
      (let ([match-vec      (ast-pattern-expand-match          ast-rec)] ; vector of ast-match-expand
            [binding-mgr   (ast-pattern-expand-match-bindings  ast-rec)] ; binding-manager hashtable
            [actions        (ast-pattern-expand-match-actions   ast-rec)] ; list of action records
            [root-op-name   (ast-pattern-expand-root-op-name   ast-rec)] ; syntax-string e.g. #'"onnx.Cast"
            [pattern-type   (ast-pattern-expand-pattern-type   ast-rec)] ; symbol: 'conversion or 'rewrite
            [raw-rewrite    (ast-pattern-expand-rewrite         ast-rec)] ; list of raw syntax objects
            [then-let-bindings (ast-pattern-expand-then-let    ast-rec)]) ; list of ast-then-let-binding-expand

        ;; Computed values — each may depend on earlier bindings in this block.
        (let* ([num-ops          (vector-length match-vec)]
               [root-op             (find-root-op match-vec root-op-name)]
               [root-result-vars    (ast-match-expand-result-var root-op)]
               [root-result-setters (generate-root-result-setters root-result-vars op)]
               ;; :rewrite :with body kept as raw syntax — forwarded to with-mlir-ops.
               ;; Rewrite vars are NOT pre-declared in the outer let; with-mlir-ops
               ;; declares them in its own let*.
               [match-vars       (collect-all-variables binding-mgr)]
               [then-let-vars    (map ast-then-let-binding-expand-var then-let-bindings)]
               [all-vars         (append match-vars then-let-vars)]
               )

          ;; Code generation — the two halves are independent of each other.
          (let ([check-code  (generate-check-code actions match-vec operands-ref)]
                [rewrite-code (generate-rewrite-code raw-rewrite pattern-type rewriter op)])

            ;; Build param list: 4 params for conversion, 2 for rewrite (no operands-ref/type-converter)
            (let ([params (if operands-ref
                              (list op operands-ref rewriter type-converter)
                              (list op rewriter))])
              (with-syntax ([fname    (ast-pattern-expand-function-name ast-rec)]
                            [(param ...) params]
                            [(var ...) all-vars]
                            [num-operations num-ops]
                            [(root-result-setter ...) root-result-setters]
                            [(then-let-binding ...) (generate-then-let-bindings then-let-bindings)]
                            [checks  check-code]
                            [rewrite rewrite-code])
                (with-syntax ([root-op op])
                  #'(define fname
                      (lambda (param ...)
                        ;; Install current-MLIRContext from the root op so that
                        ;; make-mlir-attribute and type constructors work in :then-let
                        ;; without requiring an explicit ctx argument.
                        (parameterize ([current-MLIRContext
                                        (mlir-Operation::getContext root-op)])
                          (let ([var (make-unbound-value)] ...
                                [all-operations (make-vector num-operations (make-unbound-value))])
                            root-result-setter ...
                            (if checks
                                (let* (then-let-binding ...)
                                  rewrite)
                                #f)))))))))))))

  ;;=======================================================================
  ;; Rewrite code — thin wrapper delegating to with-mlir-ops
  ;;=======================================================================
  ;;
  ;; generate-rewrite-code
  ;;
  ;; raw-body     — list of raw syntax objects (the :rewrite :with op-forms)
  ;; pattern-type — 'conversion | 'rewrite
  ;; rw / op      — syntax identifiers for the rewriter and matched operation
  ;;
  ;; Generated shape ('conversion):
  ;;   (with-RewriterBase (rw op)
  ;;     (let ([result (with-mlir-ops form ...)])
  ;;       (mlir::RewriterBase::replaceOp rw op result)
  ;;       #t))
  ;;
  ;; with-mlir-ops handles op-forms, :attrs, :regions, and :scheme escapes.
  ;; with-RewriterBase calls setInsertionPoint so
  ;; dispatches through the active rewriter or block-builder.
  (define (generate-rewrite-code raw-body pattern-type rw op)
    (if (null? raw-body)
        #'#t
        (with-syntax ([(form ...) raw-body])
          (case pattern-type
            [(conversion rewrite)
             #`(guard (exn [#t
                            ;; A Scheme exception in the rewrite body is a pattern
                            ;; failure. Emit the full condition text as an MLIR
                            ;; diagnostic so it appears in ORT's error output.
                            (mlir-emit-error! #,op
                                              (call-with-string-output-port
                                               (lambda (p) (display-condition exn p))))
                            #f])
                 (with-RewriterBase (#,rw #,op)
                                    (let ([result (with-mlir-ops #,rw form ...)])
                                      ;; result is a Value* uptr on success, or #f to signal failure.
                                      (if result
                                          (begin (mlir::RewriterBase::replaceOp #,rw #,op result) #t)
                                          #f))))]))))

  ;;=======================================================================
  ;; :then-let bindings
  ;;=======================================================================

  (define (generate-then-let-bindings then-let-list)
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
  ;; only :current-op/:attr from (crest internal keywords) are substituted.

  ;; transform-where-expr — syntactic substitution for :where expressions.
  ;;
  ;; No (:attr "name" :type) form: clients compose (:attr "name") with
  ;; explicit attr-extraction functions from (mlir IR BuiltinAttributes).
  (define (transform-where-expr where-stx op-idx)
    (let ([cur-op #`(vector-ref all-operations #,op-idx)])
      (let walk ([s where-stx])
        (syntax-case s (:current-op :attr)
          ;; Bare :current-op identifier → the matched sub-op
          [:current-op cur-op]
          ;; (:attr "name") → raw attr uptr; error if absent
          [(:attr name)
           (string? (syntax->datum #'name))
           #`(let ([%cur #,cur-op])
               (if (mlir-Operation::hasAttr? %cur name)
                   (mlir-operation-get-attr %cur name)
                   (error ':attr
                          (string-append "attribute '" name "' absent on op: ")
                          (mlir-operation-name %cur))))]
          ;; Recurse into compound forms
          [(e ...) #`(#,@(map walk (syntax->list s)))]
          ;; Atoms pass through unchanged
          [_ s]))))

  (define (generate-check-code actions match-vec operands-ref)
    (if (null? actions)
        #'#t
        (let ([checks (map (lambda (act) (action->check-code act match-vec operands-ref)) actions)])
          ;; Wrap in guard so any exception (e.g. from (:attr ...) on absent attr,
          ;; or any other runtime error during matching) becomes a silent match failure.
          #`(guard (exn [#t #f])
              (and #,@checks)))))

  (define (action->check-code action match-vec operands-ref)
    (let ([tag (car action)])
      (case tag
        [(:set-current-op)
         (let* ([fields (cdr action)]
                [op-idx (cdr (assq 'op-idx fields))]
                [var    (cdr (assq 'var fields))])
           #`(let ([def-op (mlir-value-get-defining-op #,var)])
               (and def-op
                    (begin
                      (vector-set! all-operations #,op-idx def-op)
                      #t))))]

        [(:check-op)
         (let* ([fields      (cdr action)]
                [op-idx      (cdr (assq 'op-idx fields))]
                [match-op    (vector-ref match-vec op-idx)]
                [op-name     (ast-match-expand-op-name match-op)]
                [num-results (length (ast-match-expand-result-var match-op))])
           #`(and (string=? (mlir-operation-name (vector-ref all-operations #,op-idx))
                            #,(syntax->datum op-name))
                  (= (mlir-operation-num-results (vector-ref all-operations #,op-idx))
                     #,num-results)))]

        [(:bind-operand)
         (let* ([fields      (cdr action)]
                [op-idx      (cdr (assq 'op-idx fields))]
                [var         (cdr (assq 'var fields))]
                [operand-idx (cdr (assq 'operand-idx fields))])
           #`(begin
               (set! #,var (mlir-operation-get-operand-value
                            (vector-ref all-operations #,op-idx)
                            #,operand-idx))
               #t))]

        [(:bind-argument-operand)
         (let* ([fields      (cdr action)]
                [var         (cdr (assq 'var fields))]
                [operand-idx (cdr (assq 'operand-idx fields))])
           #`(if (< #,operand-idx (array-ref-size #,operands-ref))
                 (let ([val (array-ref-at #,operands-ref #,operand-idx)])
                   (and (not (zero? val))
                        (begin (set! #,var val) #t)))
                 #f))]

        [(:check-eq)
         ;; DAG diamond: verify that the operand of this op equals an already-bound var.
         ;; get-operand retrieves a Value* from an op by index.
         ;; value-equal? checks pointer identity (same SSA value).
         (let* ([fields      (cdr action)]
                [op-idx      (cdr (assq 'op-idx fields))]
                [operand-idx (cdr (assq 'operand-idx fields))]
                [var         (cdr (assq 'var fields))])
           #`(eqv? (mlir-operation-get-operand-value
                    (vector-ref all-operations #,op-idx)
                    #,operand-idx)
                   #,var))]

        [(:bind-result)
         ;; Set a non-root result variable to the actual mlir::Value so that
         ;; :where guards and :then-let can reference it by name.
         (let* ([fields     (cdr action)]
                [op-idx     (cdr (assq 'op-idx     fields))]
                [result-idx (cdr (assq 'result-idx fields))]
                [var        (cdr (assq 'var        fields))])
           #`(begin
               (set! #,var (mlir-Operation::getResult
                            (vector-ref all-operations #,op-idx)
                            #,result-idx))
               #t))]

        [(:check-where)
         ;; Transform the where expression to substitute :current-op and (:attr ...)
         ;; before emitting.  op-idx is the index of the op this :where belongs to.
         (let* ([fields  (cdr action)]
                [op-idx  (cdr (assq 'op-idx fields))]
                [expr    (cdr (assq 'expr   fields))])
           (transform-where-expr expr op-idx))]

        [(:bind-operands)
         ;; Bind all operands of an op with optional/variadic slots via mlir-operation-get-operands.
         ;; Returns a list; bind each variable positionally with list-ref.
         (let* ([fields  (cdr action)]
                [op-idx  (cdr (assq 'op-idx fields))]
                [spec    (cdr (assq 'spec   fields))]
                [vars    (cdr (assq 'vars   fields))])
           #`(let ([%operands (mlir-operation-get-operands
                               (vector-ref all-operations #,op-idx)
                               #,@(map (lambda (s) #`'#,s) spec))])
               #,@(loop :for var :in vars
                        :for i   :from 0
                        :collect #`(set! #,var (list-ref %operands #,i)))
               #t))]

        [else
         (error 'action->check-code "Unknown action type" tag)])))

  ;;=======================================================================
  ;; Root op lookup and initialization
  ;;=======================================================================

  (define (find-root-op match-vec root-op-name-stx)
    (let ([root-op-name (syntax->datum root-op-name-stx)])
      (loop :initially := #f
            :for idx :from 0 :below (vector-length match-vec)
            :rime-with match-op := (vector-ref match-vec idx)
            :rime-with op-name  := (syntax->datum (ast-match-expand-op-name match-op))
            ;; :any ops are never the root — guard against both symbol ':any and
            ;; string ":any" (validate.sls may have normalized the symbol to string).
            :when (and (not (or (eq? op-name ':any)
                                (and (string? op-name) (string=? op-name ":any"))))
                       (string=? (if (string? op-name) op-name (symbol->string op-name))
                                 (if (string? root-op-name) root-op-name (symbol->string root-op-name))))
            :break match-op)))

  (define (generate-root-result-setters root-result-vars op-param)
    (loop :for var :in root-result-vars
          :for idx :from 0
          :collect #`(set! #,var (mlir-Operation::getResult #,op-param #,idx))))

  ;;=======================================================================
  ;; Variable collection
  ;;=======================================================================

  (define (collect-all-variables binding-mgr)
    (vector->list (hashtable-keys (binding-manager-bindings binding-mgr))))

  ;;=======================================================================
  ;; Leaf utilities
  ;;=======================================================================

  (define (make-unbound-value) (if #f #f))

  ;; Returns #t when v is an unbound pattern variable (i.e. an optional operand
  ;; that was absent at match time).  Clients use this in :then-let to check
  ;; whether an (:optional %var) was actually bound.
  (define (unbound-value? v) (eq? v (make-unbound-value)))

  (define (record->alist obj)
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
                :collect (cons (record->alist key)
                               (record->alist (hashtable-ref obj key #f)))))]
       [(record? obj)
        (let* ([rtd (record-rtd obj)]
               [field-names (vector->list (record-type-field-names rtd))])
          (loop :for name :in field-names
                :for i :from 0
                :collect (let* ([accessor (record-accessor rtd i)]
                                [value (accessor obj)])
                           (cons name (record->alist value)))))]
       [(list? obj) (map record->alist obj)]
       [(vector? obj) (vector->list (vector-map record->alist obj))]
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
