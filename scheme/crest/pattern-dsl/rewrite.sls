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
;;   (begin-mlir-code ctx op-form ...)
;;     Sequences MLIR op-forms using ctx as the builder.
;;     ctx may be a CrestRef<RewriterBase> (from a pattern callback) or
;;     a CrestOwned<OpBuilder> (from with-OpBuilder or a ^bb0 block).
;;     The correct C++ create binding is selected at runtime via %%crest:create-op!.
;;     Returns the last result (like Scheme's begin).
;;
;; op-form syntax:
;;   (%var = "op.name" (operands...) modifiers... -> result-type)   single-result
;;   ((%a %b) = "op.name" (operands...) modifiers... -> (t1 t2))   multi-result
;;   (%var = scheme-expr)                                            Scheme escape
;;   (op-name (operands...) modifiers...)                           statement (no result)
;;
;; Modifiers (any order, between operands and ->):
;;
;;   Attr modifiers:
;;   (name = val)            — set attr (val is mlir::Attribute uptr)
;;   (name = val :index)     — construct and set IntegerAttr<index>
;;   (name = val :i64)       — construct and set IntegerAttr<i64>
;;   (name = val :f32)       — construct and set FloatAttr<f32>
;;   (name = val :i32-array) — construct and set DenseI32ArrayAttr
;;   (name = val :i64-array) — construct and set DenseI64ArrayAttr
;;   (name = val :unit)      — construct and set UnitAttr
;;
;;   Region modifiers — each (^label ...) creates ONE region with ONE block:
;;   (^label ((arg : !type) ...) body ...)   — static args; use :builder in body
;;   (^label ,@type-list body ...)           — dynamic args; use (:arg N) in body
;;
;;   Consecutive shorthands = multiple regions (common case, no :region wrapper needed):
;;   (%r = "scf.if" (%c) (^then () then...) (^else () else...) -> i32)
;;
;;   One region with multiple blocks — use :region explicitly:
;;   (:region (^entry ((i : index)) body...) (^exit () exit...))
;;
;; Operands prefixed with ! are types filtered from the value operand list.
;; ,@list splices a dynamic list into the operand position:
;;   (%r = tensor.from_elements (,@%dim-vals) -> !type)
;;   (%r = some.op (v1 ,@%extra v2) -> !type)
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
                     = : -> :region
                     :string :loc :index :i64 :f32 :i32-array :i64-array :unit) expand)
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
  (define (%%crest:create-op! ctx state)
    (cond
     [(crest::isa<CrestRef<mlir::RewriterBase>>? ctx)
      (mlir::RewriterBase::create<OperationState> ctx state)]
     [(crest::isa<CrestOwned<mlir::OpBuilder>>? ctx)
      (mlir::OpBuilder::create<OperationState> ctx state)]
     [else
      (error '%%crest:create-op! "expected RewriterBase or OpBuilder" ctx)]))

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

      ;; Two entry points:
      ;;   (begin-mlir-code ctx items ...)  — explicit builder/rewriter (ctx identifier)
      ;;   (begin-mlir-code items ...)      — implicit: (%%current-builder) when first
      ;;                                      element is a list (op-form), not an identifier
      ;;
      ;; v2 flat syntax: items form a flat list that process-ops-flat scans sequentially.
      ;; Op boundaries are detected by parse-op-start; parenthesized items that don't
      ;; start an op are treated as Scheme expressions.
      (define (main)
        (syntax-case stx ()
          ;; Implicit builder: first element is NOT an identifier.
          ;; Bind via let so the recursive call receives an identifier — passing
          ;; (%%current-builder) directly would re-trigger this clause forever.
          [(_ first-item rest ...)
           (not (identifier? #'first-item))
           (with-syntax ([bld (car (generate-temporaries '(builder)))])
             #'(let ([bld (%%current-builder)])
                 (begin-mlir-code bld first-item rest ...)))]
          ;; Explicit builder (ctx is an identifier): flat-list parse (v2 + backward compat)
          [(_ ctx op ...)
           ;; Use process-ops-flat for v2 flat syntax; it also handles old-style
           ;; parenthesized op-forms via process-op delegation.
           (let* ([all-ops (syntax->list #'(op ...))]
                  [pairs   (if (and (not (null? all-ops))
                                    ;; v2 hint: first item is an identifier (not a paren form),
                                    ;; meaning the flat parser is needed.
                                    ;; Old style: every item is a parenthesized op-form.
                                    (identifier? (car all-ops)))
                               ;; v2 flat syntax: scan the whole flat list
                               (process-ops-flat all-ops 0 #'ctx)
                               ;; Old-style: each item is a complete parenthesized op-form
                               (loop :for op-stx :in all-ops
                                     :for index :from 0
                                     :append (process-op op-stx index #'ctx)))])
             (if (null? pairs)
                 #'(if #f #f)
                 (with-syntax ([(binding ...) (map make-binding pairs)]
                               [result        (car (car (reverse pairs)))])
                   #'(let* (binding ...) result))))]
          [(_) #'(if #f #f)]))


      ;;-------------------------------------------------------------------
      ;; Flat-list parser (v2 syntax)
      ;;-------------------------------------------------------------------

      ;; Detect the kind of op-start at the head of `items` (a syntax list).
      ;; Returns 'single-result, 'multi-result, 'no-result, or #f.
      ;;
      ;; single-result:  var = op.name (ops) ...
      ;; multi-result:   (v0 v1 ...) = op.name (ops) ...
      ;; no-result:      op.name (ops) ...
      (define (parse-op-start items)
        (define (syntax-pair? x)
          (pair? (syntax->datum x)))
        (cond
         ;; single-result: sym = op.name (ops)
         [(and (>= (length items) 4)
               (identifier? (list-ref items 0))
               (not (op-name? (list-ref items 0)))
               (identifier? (list-ref items 1))
               (free-identifier=? (list-ref items 1) #'=)
               (identifier? (list-ref items 2))
               (op-name? (list-ref items 2))
               (syntax-pair? (list-ref items 3)))
          'single-result]
         ;; multi-result: (v0 v1) = op.name (ops)
         [(and (>= (length items) 4)
               (syntax-pair? (list-ref items 0))
               (let ([inner (syntax->list (list-ref items 0))])
                 (and inner (for-all identifier? inner)))
               (identifier? (list-ref items 1))
               (free-identifier=? (list-ref items 1) #'=)
               (identifier? (list-ref items 2))
               (op-name? (list-ref items 2))
               (syntax-pair? (list-ref items 3)))
          'multi-result]
         ;; no-result: op.name (ops)
         [(and (>= (length items) 2)
               (identifier? (list-ref items 0))
               (op-name? (list-ref items 0))
               (syntax-pair? (list-ref items 1)))
          'no-result]
         [else #f]))

      ;; True when x is a block label identifier starting with ^.
      (define (block-label? x)
        (let ([datum (syntax->datum x)])
          (and (symbol? datum)
               (char=? #\^ (string-ref (symbol->string datum) 0)))))

      ;; Classify one modifier element for the new v2 attribute syntax.
      ;; Attribute form: (name : val) or (name : val :keyword)
      ;; Region form:    (^label ...) or (:region ...)
      ;; Loc form:       :loc  (sentinel, followed by next item)
      ;; Returns a tagged pair: (attr . setter-fn), (region . fill-fns), or (loc . stx).
      (define (classify-attr-colon m)
        (define (make-direct-setter name-str val-stx)
          (lambda (state-stx)
            (with-syntax ([state state-stx] [n name-str] [v val-stx])
              #'(mlir::OperationState::addAttribute state n v))))
        (syntax-case m (: :string :loc :index :i64 :f32 :i32-array :i64-array :unit :region)
          ;; Normalise symbol name → string name
          [(name : val . rest)
           (symbol? (syntax->datum #'name))
           (with-syntax ([str-name (datum->syntax #'name
                                                  (symbol->string (syntax->datum #'name)))])
             (classify-attr-colon #'(str-name : val . rest)))]
          ;; Typed attribute shorthands
          [(name : val :string)    (classify-attr-colon #'(name : (mlir::StringAttr::get val)))]
          [(name : val :index)     (classify-attr-colon #'(name : (mlir::IntegerAttr::get<index> val)))]
          [(name : val :i64)       (classify-attr-colon #'(name : (mlir::IntegerAttr::get<i64> val)))]
          [(name : val :f32)       (classify-attr-colon #'(name : (mlir::FloatAttr::get<f32> val)))]
          [(name : val :i32-array) (classify-attr-colon #'(name : (mlir::DenseI32ArrayAttr::get val)))]
          [(name : val :i64-array) (classify-attr-colon #'(name : (mlir::DenseI64ArrayAttr::get val)))]
          [(name : val :unit)      (classify-attr-colon #'(name : (mlir::UnitAttr::get)))]
          ;; Block region shorthand: (^label ...)  →  wrapped in :region
          [(label . _)
           (block-label? #'label)
           (classify-attr-colon #`(:region #,m))]
          ;; :loc override — (:loc expr) parenthesized form
          [(:loc e) (cons 'loc #'e)]
          ;; Terminal: plain attribute
          [(name : val)
           (string? (syntax->datum #'name))
           (cons 'attr (make-direct-setter (syntax->datum #'name) #'val))]
          ;; :region with one or more blocks
          [(:region block ...)
           (for-all (lambda (b) (block-label? (car (syntax->list b))))
                    (syntax->list #'(block ...)))
           (cons 'region (map make-block-fill (syntax->list #'(block ...))))]
          [_ (syntax-violation 'begin-mlir-code "invalid modifier" m)]))

      ;; Consume modifiers from items until we hit -> or a new op-start.
      ;; Returns (values attr-fns region-fns loc-override result-types remaining-items).
      (define (parse-modifiers-flat items builder-stx)
        (let lp ([items   items]
                 [attrs   '()]
                 [regions '()]
                 [loc     #f]
                 [types   '()])
          (cond
           ;; End of items
           [(null? items)
            (values (reverse attrs) regions loc (reverse types) '())]
           ;; -> result-type — consume one type (or type list) and continue
           [(and (identifier? (car items))
                 (free-identifier=? (car items) #'->))
            (let ([rest (cdr items)])
              (cond
               [(null? rest)
                (values (reverse attrs) regions loc (reverse types) '())]
               ;; -> (t0 t1 ...) — multi-result type list
               [(pair? (syntax->datum (car rest)))
                (let* ([tlist (syntax->list (car rest))]
                       [rest2 (cdr rest)])
                  (lp rest2 attrs regions loc (append (reverse tlist) types)))]
               ;; -> single-type
               [else
                (lp (cdr rest) attrs regions loc (cons (car rest) types))]))]
           ;; :loc followed by next item
           [(and (identifier? (car items))
                 (free-identifier=? (car items) #':loc)
                 (not (null? (cdr items))))
            (lp (cddr items) attrs regions (cadr items) types)]
           ;; Parenthesized item — could be attr modifier, region block, or (:loc e)
           [(pair? (syntax->datum (car items)))
            (let ([tagged (classify-attr-colon (car items))])
              (case (car tagged)
                [(attr)   (lp (cdr items) (cons (cdr tagged) attrs) regions loc types)]
                [(loc)    (lp (cdr items) attrs regions (cdr tagged) types)]
                [(region) (let ([region-idx (length regions)])
                            (lp (cdr items) attrs
                                (append regions (list (make-region-fill-fn region-idx (cdr tagged))))
                                loc types))]
                [else (syntax-violation 'begin-mlir-code "unexpected modifier" (car items))]))]
           ;; Any other identifier — stop (might be start of next op)
           [else
            (values (reverse attrs) regions loc (reverse types) items)])))

      ;; Scan the flat item list and produce binding descriptors.
      ;; Mutually: detect op boundary, parse modifiers, call emit-multi.
      (define (process-ops-flat items index builder-stx)
        (if (null? items)
            '()
            (let ([kind (parse-op-start items)])
              (case kind
                [(single-result)
                 (let* ([result-var (list-ref items 0)]
                        [op-name-stx (list-ref items 2)]
                        [operands-stx (list-ref items 3)]
                        [rest (list-tail items 4)])
                   (let-values ([(attr-fns region-fns loc types remaining)
                                 (parse-modifiers-flat rest builder-stx)])
                     (append
                      (emit-multi (list result-var) (op-name->str op-name-stx)
                                  (value-operands operands-stx)
                                  types attr-fns region-fns index
                                  op-name-stx builder-stx loc)
                      (process-ops-flat remaining (+ index 1) builder-stx))))]
                [(multi-result)
                 (let* ([result-vars (syntax->list (list-ref items 0))]
                        [op-name-stx (list-ref items 2)]
                        [operands-stx (list-ref items 3)]
                        [rest (list-tail items 4)])
                   (let-values ([(attr-fns region-fns loc types remaining)
                                 (parse-modifiers-flat rest builder-stx)])
                     (append
                      (emit-multi result-vars (op-name->str op-name-stx)
                                  (value-operands operands-stx)
                                  types attr-fns region-fns index
                                  op-name-stx builder-stx loc)
                      (process-ops-flat remaining (+ index 1) builder-stx))))]
                [(no-result)
                 (let* ([op-name-stx (list-ref items 0)]
                        [operands-stx (list-ref items 1)]
                        [rest (list-tail items 2)])
                   (let-values ([(attr-fns region-fns loc types remaining)
                                 (parse-modifiers-flat rest builder-stx)])
                     (append
                      (emit-multi '() (op-name->str op-name-stx)
                                  (value-operands operands-stx)
                                  types attr-fns region-fns index
                                  op-name-stx builder-stx loc)
                      (process-ops-flat remaining (+ index 1) builder-stx))))]
                [else
                 ;; Not an op-start at the item level.
                 (let ([item (car items)]
                       [rest (cdr items)])
                   (if (pair? (syntax->datum item))
                       ;; Parenthesized item: check if it's an old-style op-form
                       ;; (v = op.name ...) or (op.name ...) — delegate to process-op.
                       ;; Otherwise treat as a Scheme expression.
                       (let ([inner-items (syntax->list item)])
                         (if (and inner-items
                                  (or (parse-op-start inner-items)
                                      ;; Old-style Scheme escape: (var = expr)
                                      (and (eqv? (length inner-items) 3)
                                           (identifier? (list-ref inner-items 0))
                                           (identifier? (list-ref inner-items 1))
                                           (free-identifier=? (list-ref inner-items 1) #'=)
                                           (not (op-name? (list-ref inner-items 0))))))
                             ;; Old-style parenthesized op-form: delegate to process-op
                             (append (process-op item index builder-stx)
                                     (process-ops-flat rest (+ index 1) builder-stx))
                             ;; Plain Scheme expression
                             (let ([tmp (car (generate-temporaries '(%unused)))])
                               (cons (cons tmp item)
                                     (process-ops-flat rest (+ index 1) builder-stx)))))
                       ;; Bare identifier: skip (shouldn't happen in practice)
                       (process-ops-flat rest index builder-stx)))]))))

      ;;-------------------------------------------------------------------
      ;; Op form parser (v1 — kept for compatibility, still used by block bodies)
      ;;-------------------------------------------------------------------

      ;; Parse one op-form into a flat list of (syntax-var . syntax-expr) pairs
      ;; that become let* bindings.
      ;;
      ;; Single-result — two pairs:
      ;;   (%r = arith.constant () ("value" = 0 :index) -> i32)
      ;;   →  [(%op-tmp-<index> . (let ([new-op (with-OperationState ...)]) new-op))
      ;;        (%r             . (mlir::Operation::getResult %op-tmp-<index> 0))]
      ;;
      ;; Multi-result — one tmp pair + one pair per result variable:
      ;;   ((%a %b) = some.op (%x) -> (t1 t2))
      ;;   →  [(%op-tmp-<index> . (let ([new-op (with-OperationState ...)]) new-op))
      ;;        (%a             . (mlir::Operation::getResult %op-tmp-<index> 0))
      ;;        (%b             . (mlir::Operation::getResult %op-tmp-<index> 1))]
      ;;
      ;; Statement (no result) — one pair binding the tmp to the op itself.
      (define (process-op op-stx index builder-stx)
        (syntax-case op-stx (= ->)
          ;; Scheme escape
          [(var = expr)
           (and (identifier? #'var) (not (op-name? #'expr)))
           (list (cons #'var #'expr))]
          ;; Single-result: normalize (var) to ((var)) and result-type to (result-type)
          [(var = op (operands ...) modifiers ... -> result-type)
           (and (identifier? #'var) (op-name? #'op))
           (process-op #'((var) = op (operands ...) modifiers ... -> (result-type)) index builder-stx)]
          ;; Multi-result: #'op carries the source annotation of the op name.
          [((var ...) = op (operands ...) modifiers ... -> (result-type ...))
           (and (op-name? #'op)
                (for-all identifier? (syntax->list #'(var ...)))
                (eqv? (length (syntax->list #'(var ...)))
                      (length (syntax->list #'(result-type ...)))))
           (let-values ([(attr-setter-fns region-fill-fns loc-override)
                         (parse-modifiers #'(modifiers ...) builder-stx)])
             (emit-multi (syntax->list #'(var ...)) (op-name->str #'op)
                         (value-operands #'(operands ...))
                         (syntax->list #'(result-type ...)) attr-setter-fns
                         region-fill-fns index #'op builder-stx loc-override))]
          ;; Statement: no var, no ->.
          [(op (operands ...) modifiers ...)
           (op-name? #'op)
           (process-op #'(() = op (operands ...) modifiers ... -> ()) index builder-stx)]
          ;; Scheme expression statement — callee has no '.' so it's a Scheme call
          [(callee . args)
           (not (op-name? #'callee))
           (list (cons (car (generate-temporaries '(%unused)))
                       #'(callee . args)))]
          [_ (syntax-violation 'begin-mlir-code "invalid op form" op-stx)]))

      ;;-------------------------------------------------------------------
      ;; Modifier parser
      ;;-------------------------------------------------------------------

      ;; Parse the modifier clause between the operand list and ->.
      ;; Returns (values attr-setter-fns region-fill-fns):
      ;;   attr-setter-fns  — list of (lambda (op-stx) → setter-syntax)
      ;;   region-fill-fns  — list of (lambda (op-stx) → fill-stmt-syntax)
      ;;
      ;; Attr modifier forms:
      ;;   (name = val)            — val is a mlir::Attribute uptr; set directly
      ;;   (name = val :index)     — construct IntegerAttr<index>
      ;;   (name = val :i64)       — construct IntegerAttr<i64>
      ;;   (name = val :f32)       — construct FloatAttr<f32>
      ;;   (name = val :i32-array) — construct DenseI32ArrayAttr
      ;;   (name = val :i64-array) — construct DenseI64ArrayAttr
      ;;   (name = val :unit)      — construct UnitAttr (val ignored)
      ;;
      ;; Region modifier forms:
      ;;
      ;;   (^label ((arg : type) ...) body ...)          — one region, one block (shorthand)
      ;;   (^label builder-name ((arg : type) ...) ...)  — same, builder name in scope
      ;;
      ;;   Multiple consecutive shorthands = multiple single-block regions:
      ;;   (^then () then-body ...) (^else () else-body ...)
      ;;   → two regions; no :region wrapper needed (the common case for scf.if etc.)
      ;;
      ;;   (:region (^label ...) ...)  — one region with multiple blocks (rare)
      ;;
      ;; Examples:
      ;;   ("value" = 42 :index)                    — attr modifier
      ;;   (^bb0 () body ...)                        — one region, one block
      ;;   (^then () t ...) (^else () f ...)         — two regions (e.g. scf.if)
      ;;   (:region (^entry () ...) (^exit () ...))  — one region, two blocks
      ;; Shared block-fill factory.
      ;; block-id     — syntax identifier for the block (same object used in arg-bindings)
      ;; types-stx    — expr evaluating to the list of block arg types
      ;; arg-bindings — syntax list of let* bindings (empty for dynamic)
      ;; body-stxs    — list of body op-form syntax objects
      ;; Uses #,block-id directly in quasi-syntax to avoid with-syntax mark skew.
      (define (%%make-block-fill-lambda block-id types-stx arg-bindings body-stxs)
        (with-syntax ([bld   (car (generate-temporaries '(block-builder)))]
                      [types types-stx]
                      [(arg-binding ...) arg-bindings]
                      [(b ...) body-stxs])
          (lambda (region-stx)
            (with-syntax ([region region-stx])
              #`(let* ([#,block-id (mlir::Region::push_back<Block> region types)]
                       arg-binding ...)
                  (with-current-MLIRBlock #,block-id
                    (with-CrestObject (bld (mlir::OpBuilder::atBlockEnd #,block-id))
                      (with-current-OpBuilder bld
                        (begin-mlir-code bld b ...)))))))))

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

      ;; Parse the modifier clause between the operand list and -> (v1 old syntax).
      ;; Returns (values attr-setter-fns region-fill-fns loc-override).
      (define (parse-modifiers modifiers-stx builder-stx)
        (define (make-direct-setter name-str val-stx)
          (lambda (state-stx)
            (with-syntax ([state state-stx] [n name-str] [v val-stx])
              #'(mlir::OperationState::addAttribute state n v))))
        (define (classify m)
          (syntax-case m (= :string :loc :index :i64 :f32 :i32-array :i64-array :unit :region)
            [(name = val . rest) (symbol? (syntax->datum #'name))
             (with-syntax ([str-name (datum->syntax #'name
                                                    (symbol->string (syntax->datum #'name)))])
               (classify #'(str-name = val . rest)))]
            [(name = val :string)    (classify #'(name = (mlir::StringAttr::get val)))]
            [(name = val :index)     (classify #'(name = (mlir::IntegerAttr::get<index> val)))]
            [(name = val :i64)       (classify #'(name = (mlir::IntegerAttr::get<i64> val)))]
            [(name = val :f32)       (classify #'(name = (mlir::FloatAttr::get<f32> val)))]
            [(name = val :i32-array) (classify #'(name = (mlir::DenseI32ArrayAttr::get val)))]
            [(name = val :i64-array) (classify #'(name = (mlir::DenseI64ArrayAttr::get val)))]
            [(name = val :unit)      (classify #'(name = (mlir::UnitAttr::get)))]
            [(label . _) (block-label? #'label) (classify #`(:region #,m))]
            [(:loc e)  (cons 'loc #'e)]
            [(name = val) (string? (syntax->datum #'name))
             (cons 'attr (make-direct-setter (syntax->datum #'name) #'val))]
            [(:region block ...)
             (for-all (lambda (b) (block-label? (car (syntax->list b))))
                      (syntax->list #'(block ...)))
             (cons 'region (map make-block-fill (syntax->list #'(block ...))))]
            [_ (syntax-violation 'begin-mlir-code "invalid modifier entry" m)]))
        (define (split-modifiers tagged)
          (values
           (loop :for e :in tagged :if (eq? (car e) 'attr) :collect (cdr e))
           (loop :for e :in (filter (lambda (e) (eq? (car e) 'region)) tagged)
                 :for idx :from 0
                 :collect (make-region-fill-fn idx (cdr e)))
           (let ([locs (filter (lambda (e) (eq? (car e) 'loc)) tagged)])
             (if (null? locs) #f (cdr (car locs))))))
        (split-modifiers
         (let lp ([ms (syntax->list modifiers-stx)] [acc '()])
           (cond
            [(null? ms) (reverse acc)]
            [(and (identifier? (car ms))
                  (free-identifier=? (car ms) (datum->syntax (car ms) ':loc))
                  (not (null? (cdr ms))))
             (lp (cddr ms) (cons (cons 'loc (cadr ms)) acc))]
            [else (lp (cdr ms) (cons (classify (car ms)) acc))]))))
      ;;-------------------------------------------------------------------
      ;; Code emitters
      ;;-------------------------------------------------------------------

      ;; Binding-descriptor protocol
      ;; ─────────────────────────────────────────────────────────────────────
      ;; emit-multi (and process-op, which delegates to it) returns a flat list
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
      ;; Parameters:
      ;;   result-vars   — Scheme list of result variable syntax objects
      ;;   op-name       — string op name, e.g. "arith.constant"
      ;;   operands      — Scheme list of value operand syntax objects
      ;;   result-types  — Scheme list of result-type syntax objects (may be empty)
      ;;   attr-setter-fns  — Scheme list of closures (lambda (new-op-stx) → setter-syntax)
      ;;   region-fill-fns  — Scheme list of closures (lambda (new-op-stx) → fill-stmt-syntax)
      ;;   index            — integer op index, used to generate a unique %op-tmp-N name
      ;; Generate a unique gensym named %op-tmp-N for the Nth op in the form.
      (define (op-tmp-id n)
        (car (generate-temporaries
              (list (string->symbol (string-append "%op-tmp-" (number->string n)))))))

      (define (emit-multi result-vars   ; syntax list — result variable names
                          op-name       ; string — e.g. "arith.constant"
                          operands      ; syntax expr — (list v1 v2 ...)
                          result-types  ; syntax list — empty for statements
                          attr-setter-fns   ; list of (lambda (op-stx) → setter-stx)
                          region-fill-fns   ; list of (lambda (op-stx) → fill-stx)
                          index         ; integer — op position in begin-mlir-code
                          op-name-stx   ; syntax — carries source location annotation
                          builder-stx   ; syntax — the active builder expression
                          loc-override) ; syntax or #f — runtime mlir::Location override
        (let* ([nregions  (length region-fill-fns)]  ; number of region modifiers
               [op-var   (op-tmp-id index)]           ; %op-tmp-N — outer let* binding
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
               [builder        builder-stx]      ; active builder
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
                             (%%crest:create-op! builder state))])
                       region-fill-stmt ...        ; fill regions — after create
                       op-tmp))
             ;; Bindings for result variables — loop returns '() when result-vars is empty,
             ;; which happens for zero-result ops (length guard in process-op enforces this).
             ;; TODO: add :current-op in begin-mlir-code to capture zero-result ops by name.
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
