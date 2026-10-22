#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest pattern-dsl rewrite) — expression-level MLIR operation builder
;;
;; Provides:
;;
;;   (begin-mlir-code builder op-form ...)
;;     Sequences MLIR op-forms using builder as the active builder.
;;     builder may be a CrestRef<RewriterBase> (from a pattern callback) or
;;     a CrestOwned<OpBuilder> (from with-OpBuilder or a ^bb0 block).
;;     The correct C++ create binding is selected at runtime via %%crest:create-op!.
;;     Returns the last result (like Scheme's begin).
;;
;; v2 flat-list syntax — items are scanned sequentially without outer parens per op:
;;
;;   var = op.name (operands...) modifiers... -> result-type      single-result
;;   (v0 v1) = op.name (operands...) modifiers... -> (t0 t1)     multi-result
;;   op.name (operands...) modifiers...                           statement (no result)
;;   (scheme-expr ...)                                            Scheme expression
;;
;; Modifiers (any order, between operands and ->):
;;
;;   Attr modifiers:
;;   (name : val)            — set attr (val is mlir::Attribute uptr)
;;   (name : val :index)     — construct and set IntegerAttr<index>
;;   (name : val :i64)       — construct and set IntegerAttr<i64>
;;   (name : val :f32)       — construct and set FloatAttr<f32>
;;   (name : val :i32-array) — construct and set DenseI32ArrayAttr
;;   (name : val :i64-array) — construct and set DenseI64ArrayAttr
;;   (name : val :unit)      — construct and set UnitAttr
;;   (name : val :string)    — construct and set StringAttr
;;
;;   Region modifiers — each (^label ...) creates ONE region with ONE block:
;;   (^label ((arg : !type) ...) body ...)   — static args; use :builder in body
;;   (^label ,@type-list body ...)           — dynamic args; use (:arg N) in body
;;
;;   Consecutive shorthands = multiple regions (common case, no :region wrapper needed):
;;   r = scf.if (c) (^then () then...) (^else () else...) -> i32
;;
;;   One region with multiple blocks — use :region explicitly:
;;   (:region (^entry ((i : index)) body...) (^exit () exit...))
;;
;;   Location override:
;;   (:loc expr)             — runtime mlir::Location for this op
;;
;; ,@list splices a dynamic list into the operand position:
;;   r = tensor.from_elements (,@dim-vals) -> !type
;;   r = some.op (v1 ,@extra v2) -> !type
;;
;;===----------------------------------------------------------------------===;;

(library (crest pattern-dsl rewrite)
  (export begin-mlir-code)

  (import (except (rnrs (6)) =)
          (only (chezscheme) syntax->list syntax->datum parameterize)
          (rename (rime loop) (:with :rime-with))
          (for (rename (rime loop) (:with :rime-with)) expand)
          (for (only (crest pattern-dsl srcloc) syntax->file+line+col) expand)
          (for (only (crest pattern-dsl keywords)
                     = : -> :region :loc
                     :string :index
                     :i8 :i16 :i32 :i64
                     :f32 :f64
                     :i8-array :i16-array :i32-array :i64-array
                     :unit) expand)
          (for (mlir IR BuiltinAttributes) expand)
          ;; Runtime predicates and create bindings for %%crest:create-op! dispatch
          (only (mlir IR PatternMatch)
                crest::isa<CrestRef<mlir::RewriterBase>>?
                mlir::RewriterBase::create<OperationState>
                current-RewriterBase)
          (only (mlir IR Builders)
                crest::isa<CrestOwned<mlir::OpBuilder>>?
                mlir::OpBuilder::create<OperationState>
                current-OpBuilder)
          (only (mlir support array-ref) with-CrestObject)
          (for (only (mlir IR Builders)
                     mlir::OpBuilder::atBlockEnd
                     with-current-OpBuilder) expand)
          (for (only (mlir IR OperationSupport)
                     mlir::OperationState::addOperands
                     mlir::OperationState::addTypes
                     mlir::OperationState::addRegion
                     mlir::OperationState::addAttribute
                     with-OperationState) expand)
          (for (only (mlir IR Location)
                     mlir::UnknownLoc::get
                     mlir::FileLineColLoc::get) expand)
          (for (only (mlir IR Region) mlir::Region::push_back<Block>) expand)
          (for (only (mlir IR Block)
                     mlir::Block::getArgument
                     current-MLIRBlock
                     with-current-MLIRBlock) expand)
          (only (mlir IR Block) current-MLIRBlock with-current-MLIRBlock)
          (for (only (mlir IR Operation) mlir::Operation::getRegion) expand)
          (for (only (mlir IR Operation) mlir::Operation::getResult) expand)
          (for (only (crest pattern-dsl ast)
                     make-ast-emit-op ast-emit-op?
                     ast-emit-op-result-vars ast-emit-op-op-name ast-emit-op-op-name-stx
                     ast-emit-op-operands ast-emit-op-attr-setters ast-emit-op-region-fills
                     ast-emit-op-loc-override ast-emit-op-result-types) expand))


  ;;===--------------------------------------------------------------------===;;
  ;; Runtime create dispatcher
  ;;===--------------------------------------------------------------------===;;

  ;; Returns the currently active builder: the RewriterBase (at :rewrite level)
  ;; or the OpBuilder (inside a ^bb0 block). Error if neither is set.
  ;; current-OpBuilder (block body) takes precedence over current-RewriterBase (:rewrite level)
  ;; so that :builder inside a ^bb0 body gives the block's builder, not the outer rewriter.
  (define (%%current-builder)
    (or (current-OpBuilder) (current-RewriterBase)
        (error '%%current-builder "no active builder — use begin-mlir-code inside :rewrite :with or a ^bb0 block")))

  ;; Select the correct C++ create binding based on the CREST wrapper type.
  ;; - CrestRef<RewriterBase>  → mlir::RewriterBase::create<OperationState>
  ;; - CrestOwned<OpBuilder>   → mlir::OpBuilder::create<OperationState>
  (define (%%crest:create-op! builder state)
    (cond
     [(crest::isa<CrestRef<mlir::RewriterBase>>? builder)
      (mlir::RewriterBase::create<OperationState> builder state)]
     [(crest::isa<CrestOwned<mlir::OpBuilder>>? builder)
      (mlir::OpBuilder::create<OperationState> builder state)]
     [else
      (error '%%crest:create-op! "expected RewriterBase or OpBuilder" builder)]))

  ;; Install builder into the appropriate dynamic parameter, then call thunk.
  ;; This ensures (%%current-builder) works inside the op sequence and that
  ;; :builder in block bodies resolves correctly even for direct begin-mlir-code calls.
  (define (%%with-active-builder builder thunk)
    (cond
     [(crest::isa<CrestRef<mlir::RewriterBase>>? builder)
      (parameterize ([current-RewriterBase builder]) (thunk))]
     [(crest::isa<CrestOwned<mlir::OpBuilder>>? builder)
      (parameterize ([current-OpBuilder builder]) (thunk))]
     [else
      (error '%%with-active-builder "expected RewriterBase or OpBuilder" builder)]))

  ;;===--------------------------------------------------------------------===;;
  ;; begin-mlir-code
  ;;===--------------------------------------------------------------------===;;

  ;; NOTE: the = symbol in op-forms must be the DSL = from (crest pattern-dsl keywords),
  ;; not the R6RS numeric =. Libraries using (except (rnrs) =) satisfy this;
  ;; others must import (only (crest pattern-dsl keywords) =) explicitly.
  (define-syntax begin-mlir-code
    (lambda (stx)

      ;;-------------------------------------------------------------------
      ;; Source location helpers — extract Scheme source loc at expand time
      ;;-------------------------------------------------------------------

      ;; Derive mlir::Location expr from a syntax object's source annotation.
      ;; Falls back to mlir::UnknownLoc::get when source info is unavailable.
      (define (syntax->mlir-loc-expr op-stx)
        (let ([loc (syntax->file+line+col op-stx)])
          (if loc
              #`(apply mlir::FileLineColLoc::get '#,loc)
              #'(mlir::UnknownLoc::get))))

      ;;-------------------------------------------------------------------
      ;; Main entry
      ;;-------------------------------------------------------------------

      ;; (begin-mlir-code builder-expr op ...)
      ;;   builder-expr — any expression yielding a CrestRef<RewriterBase> or
      ;;                  CrestOwned<OpBuilder>, e.g. an identifier, (%%current-builder),
      ;;                  or (current-OpBuilder).
      ;;   If builder-expr is already an identifier it is used directly.
      ;;   Otherwise it is bound to a fresh gensym so the flat-list parse always
      ;;   receives a stable identifier — this avoids re-evaluating the expression
      ;;   once per op and prevents infinite recursion.
      ;;
      ;; v2 flat syntax: items form a flat list that process-ops-flat scans sequentially.
      ;; Op boundaries are detected by parse-next; parenthesized items that don't
      ;; start an op are treated as Scheme expressions.
      (define (main)
        (syntax-case stx ()
          ;; builder is already an identifier — use it directly.
          [(_ builder op ...)
           (identifier? #'builder)
           (let ([pairs (process-ops-flat #'(op ...))])
             (if (null? pairs)
                 #'(if #f #f)
                 (with-syntax ([(binding ...) (map make-binding pairs)]
                               [result        (car (car (reverse pairs)))])
                   #'(%%with-active-builder builder
                                            (lambda () (let* (binding ...) result))))))]
          ;; builder-expr is a non-identifier expression — bind to a gensym so the
          ;; recursive call always receives a stable identifier.  This avoids both
          ;; re-evaluating the expression once per op and infinite recursion.
          [(_ builder-expr op ...)
           (with-syntax ([builder (car (generate-temporaries '(builder)))])
             #'(let ([builder builder-expr])
                 (begin-mlir-code builder op ...)))]
          [(_) (syntax-violation 'begin-mlir-code "expected (begin-mlir-code builder op ...)" stx)]))


      ;;-------------------------------------------------------------------
      ;; Flat-list parser (v2 syntax)
      ;;-------------------------------------------------------------------

      ;; True when x is a block label identifier starting with ^.
      (define (block-label? x)
        (let ([datum (syntax->datum x)])
          (and (symbol? datum)
               (char=? #\^ (string-ref (symbol->string datum) 0)))))

      ;; Classify one modifier element for the new v2 attribute syntax.
      ;; Attribute form: (name : val) or (name : val :keyword)
      ;; Region form:    (^label ...) or (:region ...)
      ;; Loc form:       (:loc expr)
      ;; Returns a tagged pair: (attr . setter-fn), (region . fill-fns), or (loc . stx).
      ;;
      ;; Uses datum comparison (eq?) instead of free-identifier=? for keywords
      ;; to avoid cross-phase issues when call sites import keywords at different phases.
      ;; Consume modifiers from items (a syntax object) until -> or a new op-start.
      ;; Returns (values attr-fns region-fns loc-override result-types remaining)
      ;; where remaining is a syntax object.
      (define (parse-modifiers-flat items)
        ;; Build a runtime (addAttribute state name val) setter closure.
        (define (%%make-attr-setter name val-stx)
          (let ([name-str (if (symbol? name) (symbol->string name) name)])
            (lambda (state-stx)
              (with-syntax ([state state-stx] [n name-str] [v val-stx])
                #'(mlir::OperationState::addAttribute state n v)))))
        (let lp ([items   items]
                 [attrs   '()]
                 [regions '()]
                 [loc     #f]
                 [types   '()])
          (syntax-case items (-> :loc :region : :string :index
                                 :i8 :i16 :i32 :i64 :f32 :f64
                                 :i8-array :i16-array :i32-array :i64-array :unit)
            ;; -> type-list, continue accumulating types
            [(-> (result-type ...) . rest)
             (lp #'rest attrs regions loc (append types (syntax->list #'(result-type ...))))]
            ;; -> single-type, continue accumulating types
            [(-> type . rest)
             (lp #'rest attrs regions loc (append types (list #'type)))]
            ;; :loc loc-expr (bare :loc token)
            [(:loc loc-expr . rest)
             (lp #'rest attrs regions #'loc-expr types)]
            ;; (:loc expr) parenthesized
            [((:loc loc-expr) . rest)
             (lp #'rest attrs regions #'loc-expr types)]
            ;; (^label body ...) — single-block region shorthand
            [((bb body ...) . rest)
             (block-label? #'bb)
             (let ([region-idx (length regions)])
               (lp #'rest attrs
                   (append regions
                           (list (make-region-fill-fn region-idx
                                                      (list (make-block-fill #'(bb body ...))))))
                   loc types))]
            ;; (:region (^label body ...) ...) — one region, multiple blocks
            [((:region block ...) . rest)
             (for-all (lambda (b) (block-label? (car (syntax->list b))))
                      (syntax->list #'(block ...)))
             (let ([region-idx (length regions)])
               (lp #'rest attrs
                   (append regions
                           (list (make-region-fill-fn region-idx
                                                      (map make-block-fill
                                                           (syntax->list #'(block ...))))))
                   loc types))]
            ;; (name : val :kw) — attribute with type-constructor keyword
            [((name : val :string) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::StringAttr::get val))
                              attrs) regions loc types)]
            [((name : val :index) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::IntegerAttr::get<index> val))
                              attrs) regions loc types)]
            [((name : val :i8) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::IntegerAttr::get<i8> val))
                              attrs) regions loc types)]
            [((name : val :i16) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::IntegerAttr::get<i16> val))
                              attrs) regions loc types)]
            [((name : val :i32) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::IntegerAttr::get<i32> val))
                              attrs) regions loc types)]
            [((name : val :i64) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::IntegerAttr::get<i64> val))
                              attrs) regions loc types)]
            [((name : val :f32) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::FloatAttr::get<f32> val))
                              attrs) regions loc types)]
            [((name : val :f64) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::FloatAttr::get<f64> val))
                              attrs) regions loc types)]
            [((name : val :i8-array) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::DenseI8ArrayAttr::get val))
                              attrs) regions loc types)]
            [((name : val :i16-array) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::DenseI16ArrayAttr::get val))
                              attrs) regions loc types)]
            [((name : val :i32-array) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::DenseI32ArrayAttr::get val))
                              attrs) regions loc types)]
            [((name : val :i64-array) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::DenseI64ArrayAttr::get val))
                              attrs) regions loc types)]
            [((name : val :unit) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name)
                                                  #'(mlir::UnitAttr::get))
                              attrs) regions loc types)]
            ;; (name : val) — raw mlir::Attribute
            [((name : val) . rest)
             (lp #'rest (cons (%%make-attr-setter (syntax->datum #'name) #'val)
                              attrs) regions loc types)]
            ;; anything else — stop
            [(otherwise ...)
             (values (reverse attrs) regions loc (reverse types) #'(otherwise ...))])))

      ;; Returns (values head remaining):
      ;;   (values #f #f)           — items is empty
      ;;   (values ast-emit-op stx) — next item(s) form an MLIR op
      ;;   (values expr-stx stx)    — next item is a Scheme expression
      (define (parse-next items)
        (syntax-case items (=)
          [() (values #f #f)]
          ;; no-result: op.name (operands) ... — normalize to (() = op ...)
          [(op (operands ...) . rest)
           (op-name? #'op)
           (parse-next #'(() = op (operands ...) . rest))]
          ;; single-result: var = op ... — normalize to ((var) = op ...)
          [(var = op (operands ...) . rest)
           (and (identifier? #'var) (op-name? #'op))
           (parse-next #'((var) = op (operands ...) . rest))]
          ;; multi-result: (v ...) = op ... — canonical form, build ast-emit-op
          [((v ...) = op (operands ...) . rest)
           (and (for-all identifier? (syntax->list #'(v ...)))
                (op-name? #'op))
           (let-values ([(attr-fns region-fns loc types remaining)
                         (parse-modifiers-flat #'rest)])
             (values (make-ast-emit-op
                      (syntax->list #'(v ...)) (op-name->str #'op) #'op
                      (value-operands #'(operands ...))
                      attr-fns region-fns loc types)
                     remaining))]
          ;; Scheme expression — consume one item
          [(expr . rest)
           (values #'expr #'rest)]))

      ;; Scan the flat item list and produce binding descriptors.
      (define (process-ops-flat items)
        (let-values ([(head remaining) (parse-next items)])
          (if (not head)
              '()
              (append
               (if (ast-emit-op? head)
                   (emit-multi head)
                   (list (cons (car (generate-temporaries '(%unused))) head)))
               (process-ops-flat remaining)))))

      ;; Shared block-fill factory.
      ;; block-id     — syntax identifier for the block (same object used in arg-bindings)
      ;; types-stx    — expr evaluating to the list of block arg types
      ;; arg-bindings — syntax list of let* bindings (empty for dynamic)
      ;; body-stxs    — list of body op-form syntax objects
      ;; Uses #,block-id directly in quasi-syntax to avoid with-syntax mark skew.
      (define (%%make-block-fill-lambda block-id types-stx arg-bindings body-stxs)
        (with-syntax ([builder (car (generate-temporaries '(block-builder)))]
                      [types   types-stx]
                      [(arg-binding ...) arg-bindings]
                      [(b ...) body-stxs])
          (lambda (region-stx)
            (with-syntax ([region region-stx])
              #`(let* ([#,block-id (mlir::Region::push_back<Block> region types)]
                       arg-binding ...)
                  (with-current-MLIRBlock #,block-id
                    (with-CrestObject (builder (mlir::OpBuilder::atBlockEnd #,block-id))
                      (with-current-OpBuilder builder
                        (begin-mlir-code builder b ...)))))))))

      ;; Returns a fill-fn: (lambda (region-stx) → syntax).
      ;; block-id extracted before syntax-case so both branches share it.
      (define (make-block-fill blk)
        (let ([block-id (car (generate-temporaries '(block)))])
          (syntax-case blk (: unquote-splicing)
            ;; Dynamic: (^label ,@types-expr body ...) — no arg bindings
            [(label (unquote-splicing types-expr) . body)
             (%%make-block-fill-lambda block-id #'types-expr '() (syntax->list #'body))]
            ;; Static: (^label ((arg : type) ...) body ...) — bind arg names
            [(label ((arg : type) ...) . body)
             (for-all identifier? (syntax->list #'(arg ...)))
             (%%make-block-fill-lambda
              block-id
              #'(list type ...)
              (loop :for var :in (syntax->list #'(arg ...))
                    :for i   :from 0
                    :collect #`(#,var (mlir::Block::getArgument #,block-id #,i)))
              (syntax->list #'body))])))

      (define (make-region-fill-fn region-index block-fill-fns)
        (lambda (op-stx)
          ;; region-id must be in scope as a Scheme value before with-syntax
          ;; because (map (fn region-id) ...) runs during binding evaluation —
          ;; with-syntax bindings are parallel, so [region-id ...] wouldn't help.
          (let ([region-id (car (generate-temporaries '(region)))])
            (with-syntax ([new-op     op-stx]
                          [region-idx region-index]
                          [(block-fill-stmt ...)
                           (map (lambda (fn) (fn region-id)) block-fill-fns)])
              #`(let ([#,region-id (mlir::Operation::getRegion new-op region-idx)])
                  block-fill-stmt ...)))))

      ;;-------------------------------------------------------------------
      ;; Code emitters
      ;;-------------------------------------------------------------------

      ;; Binding-descriptor protocol
      ;; ─────────────────────────────────────────────────────────────────────
      ;; emit-multi returns a flat list
      ;; of binding-descriptors, each a SCHEME CONS CELL:
      ;;   (cons var-syntax expr-syntax)   — a pair of two syntax objects
      ;; make-binding deconstructs each with plain (car d) / (cdr d).
      ;; main collects all descriptors across the op sequence and assembles them
      ;; into a single (let* ((var expr) ...) result) expansion.
      ;;
      ;; emit-multi always produces at least one descriptor for the Operation*:
      ;;   (op-tmp . (let ([op (with-OperationState ...)]) setter... fills... op))
      ;;
      ;; Plus one descriptor per result variable (empty for zero-result ops):
      ;;   (%var . (mlir::Operation::getResult op-tmp i))
      ;;
      ;; Generate a unique gensym for the Operation* temp binding.
      (define (op-tmp-id) (car (generate-temporaries '(%op-tmp))))

      (define (emit-multi ast)
        (let* ([result-vars     (ast-emit-op-result-vars  ast)]
               [op-name         (ast-emit-op-op-name      ast)]
               [operands        (ast-emit-op-operands     ast)]
               [result-types    (ast-emit-op-result-types ast)]
               [attr-setter-fns (ast-emit-op-attr-setters ast)]
               [region-fill-fns (ast-emit-op-region-fills ast)]
               [op-name-stx     (ast-emit-op-op-name-stx  ast)]
               [loc-override    (ast-emit-op-loc-override ast)]
               [nregions  (length region-fill-fns)]  ; number of region modifiers
               [op-var   (op-tmp-id)]                 ; gensym for the Operation*
               [state-id (car (generate-temporaries '(state)))]  ; gensym for OperationState
               ;; Generate N addRegion calls using state-id directly via #`
               ;; (can't use the 'state pattern var — with-syntax bindings are parallel).
               [addregion-calls
                (loop :for i :from 0 :below nregions
                      :collect #`(mlir::OperationState::addRegion #,state-id))])
          (with-syntax
              ([operands-expr  operands]         ; runtime operand list expr
               [name           op-name]          ; string literal
               [(result-type ...) result-types]  ; result type exprs
               [op-tmp         op-var]           ; %op-tmp-N exposed to callers
               [state          state-id]         ; gensym for OperationState binding
               ;; Setters call addAttribute on state BEFORE create (correct MLIR idiom).
               ;; state-id threads the gensym to setter closures — no literal #'state.
               [(setter ...)
                (map (lambda (fn) (fn state-id)) attr-setter-fns)]
               ;; Region fills use getRegion AFTER create — inserting ops into a
               ;; pre-OperationState block violates MLIR's parent-op invariants.
               [(region-fill-stmt ...)
                (map (lambda (fn) (fn op-var)) region-fill-fns)]
               [(addregion-call ...) addregion-calls]
               [source-loc (if loc-override loc-override (syntax->mlir-loc-expr op-name-stx))])
            (cons
             ;; Binding descriptor: op-tmp bound to the created Operation*.
             ;; Attributes set in OperationState (before create);
             ;; region slots pre-allocated in OperationState, filled post-create.
             (cons #'op-tmp
                   #'(let ([op-tmp
                            (with-OperationState
                             (state source-loc name)
                             (for-each
                              (lambda (v) (mlir::OperationState::addOperands state v))
                              operands-expr)
                             (for-each
                              (lambda (t) (mlir::OperationState::addTypes state t))
                              (list result-type ...))
                             setter ...           ; addAttribute — before create
                             addregion-call ...   ; addRegion — pre-allocate slots
                             (%%crest:create-op! (%%current-builder) state))])
                       region-fill-stmt ...        ; fill regions — after create
                       op-tmp))
             ;; Bindings for result variables — loop returns '() when result-vars is empty,
             ;; which happens for no-result ops (process-ops-flat passes '() for result-vars).
             (loop :for var :in result-vars
                   :for i   :from 0
                   :collect (cons var #`(mlir::Operation::getResult op-tmp #,i)))))))



      ;;-------------------------------------------------------------------
      ;; Leaf helpers
      ;;-------------------------------------------------------------------

      ;; Lift a (var-stx . expr-stx) cons cell into a syntax binding (var expr).
      (define (make-binding pair)
        (with-syntax ([var (car pair)] [expr (cdr pair)]) #'(var expr)))

      (define (%%string-contains string character)
        (loop :initially := #f
              :for x :in-string string
              :break #t :if (char=? x character)))

      (define (op-name? x)
        (let ([datum (syntax->datum x)])
          (cond
           [(string? datum) (%%string-contains datum #\.)]
           [(symbol? datum) (%%string-contains (symbol->string datum) #\.)]
           [#t #f])))
      (define (op-name->str x)
        (let ([datum (syntax->datum x)])
          (if (string? datum) datum (symbol->string datum))))

      ;; Build a runtime expression for the operand list from (operands ...).
      ;; ,@list splices a dynamic list: (v1 ,@%more v2) → (append (list v1) %more (list v2))
      ;; (:arg N) is a shorthand for (mlir::Block::getArgument block N) — only valid
      ;; when 'block' is in scope, i.e. inside the body of a (^label ...) block form.
      ;; Each operand converts to a chunk; (append chunk ...) flattens them.
      (define (value-operands operands-stx)
        (define (convert x)
          (syntax-case x (unquote-splicing)
            [(unquote-splicing expr) #'expr]  ; ,@expr → spliced list
            [val          #'(list val)]))
        (with-syntax ([(chunk ...) (map convert (syntax->list operands-stx))])
          #'(append chunk ...)))

      (main)))


  ) ;; end library (crest pattern-dsl rewrite)
