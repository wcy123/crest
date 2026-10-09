#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest internal rewrite) — expression-level MLIR operation builder
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
;;   (^label ((arg : !type) ...) body ...)         — unnamed builder
;;   (^label builder-name ((arg : !type) ...) ...) — builder name in scope for body
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

(library (crest internal rewrite)
  (export begin-mlir-code)

  (import (except (rnrs (6)) =)
          (only (chezscheme) syntax->list syntax->datum parameterize
                syntax->annotation annotation? annotation-source
                source-object? source-object-sfd source-object-bfp
                source-file-descriptor-path)
          (rename (rime loop) (:with :rime-with))
          (for (rename (rime loop) (:with :rime-with)) expand)
          (for (only (crest internal keywords) = : -> :region) expand)
          (mlir IR BuiltinAttributes)
          (for (mlir IR BuiltinAttributes) expand)
          ;; Runtime predicates and create bindings for %%crest:create-op! dispatch
          (only (mlir IR PatternMatch)
                crest::isa<CrestRef<mlir::RewriterBase>>?
                mlir::RewriterBase::create<OperationState>)
          (only (mlir IR Builders)
                crest::isa<CrestOwned<mlir::OpBuilder>>?
                mlir::OpBuilder::create<OperationState>)
          (only (mlir support array-ref) CrestObject::delete)
          (for (only (mlir IR Builders)
                     mlir::OpBuilder::atBlockEnd) expand)
          (for (only (mlir IR OperationSupport)
                     mlir::OperationState::addOperands
                     mlir::OperationState::addTypes
                     mlir::OperationState::addRegion
                     with-OperationState) expand)
          (for (only (mlir IR Operation) mlir::Operation::getRegion) expand)
          (for (only (mlir IR Location)
                     mlir::UnknownLoc::get
                     mlir::FileLineColLoc::get) expand)
          (for (only (mlir IR Region) mlir::Region::push_back<Block>) expand)
          (for (only (mlir IR Block) mlir::Block::getArgument) expand)
          (for (rename (only (mlir IR Operation) mlir::Operation::getContext
                             mlir::Operation::getResult
                             mlir::Operation::setAttr!)
                       (mlir::Operation::getContext    mlir-Operation::getContext)
                       (mlir::Operation::getResult     mlir-Operation::getResult)
                       (mlir::Operation::setAttr!      mlir-operation-set-attribute!)) expand))

  ;;===--------------------------------------------------------------------===;;
  ;; Attr-constructor dispatch — used by the (name = val :type) modifier
  ;; form to build an MLIR attribute at runtime.  Replaces the old generic
  ;; generic mlir-make-attr dispatcher (removed with (mlir core attribute)).
  ;;
  ;; ctx is passed but unused here — the explicit constructors from
  ;; (mlir IR BuiltinAttributes) read current-MLIRContext internally.
  ;;===--------------------------------------------------------------------===;;
  (define (%%make-attr-by-type _ctx type val)
    (case type
      [(index :index)           (mlir::IntegerAttr::get<index> val)]
      [(i32-array :i32-array)   (mlir::DenseI32ArrayAttr::get val)]
      [(i64-array :i64-array)   (mlir::DenseI64ArrayAttr::get val)]
      [(i64 :i64)               (mlir::IntegerAttr::get<i64> val)]
      [(f32 :f32)               (mlir::FloatAttr::get<f32> val)]
      [(unit :unit)             (mlir::UnitAttr::get)]
      [else (error '%%make-attr-by-type "unknown attr type in rewrite DSL" type)]))

  ;;===--------------------------------------------------------------------===;;
  ;; Runtime create dispatcher
  ;;===--------------------------------------------------------------------===;;

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

  ;; NOTE: the = symbol in op-forms must be the DSL = from (crest internal keywords),
  ;; not the R6RS numeric =. Libraries using (except (rnrs) =) satisfy this;
  ;; others must import (only (crest internal keywords) =) explicitly.
  (define-syntax begin-mlir-code
    (lambda (stx)

      ;;-------------------------------------------------------------------
      ;; Source location helpers — extract Scheme source loc at expand time
      ;;-------------------------------------------------------------------

      (define (bfp->line+col filename bfp)
        (guard (e [#t (values 1 1)])
          (call-with-port
              (transcoded-port (open-file-input-port filename)
                               (make-transcoder (utf-8-codec) (eol-style none)))
            (lambda (p)
              (let loop ([pos 0] [line 1] [col 1])
                (if (>= pos bfp)
                    (values line col)
                    (let ([ch (read-char p)])
                      (cond
                       [(eof-object? ch) (values line col)]
                       [(char=? ch #\newline) (loop (+ pos 1) (+ line 1) 1)]
                       [else (loop (+ pos 1) line (+ col 1))]))))))))

      ;; At expand time: derive mlir::Location expr from a syntax object's
      ;; source annotation.  Falls back to mlir::UnknownLoc::get when
      ;; source info is unavailable.
      (define (syntax->mlir-loc-expr op-stx)
        (let* ([ann (syntax->annotation op-stx)]
               [src (and (annotation? ann) (annotation-source ann))]
               [sfd (and (source-object? src) (source-object-sfd src))]
               [bfp (and sfd (source-object-bfp src))])
          (if sfd
              (let ([file (source-file-descriptor-path sfd)])
                (let-values ([(line col) (bfp->line+col file bfp)])
                  #`(mlir::FileLineColLoc::get #,file #,line #,col)))
              #'(mlir::UnknownLoc::get))))

      ;;-------------------------------------------------------------------
      ;; Main entry
      ;;-------------------------------------------------------------------

      ;; Single case: ctx is any builder (CrestRef<RewriterBase> or
      ;; CrestOwned<OpBuilder>). %%crest:create-op! dispatches at runtime.
      (define (main)
        (syntax-case stx ()
          [(_ ctx op ...)
           (let ([pairs (loop :for op-stx :in (syntax->list #'(op ...))
                              :for index :from 0
                              :append (process-op op-stx index #'ctx))])
             (if (null? pairs)
                 #'(if #f #f)
                 (with-syntax ([(binding ...) (loop :for pair :in pairs
                                                    :collect (make-binding pair))]
                               [result        (car (car (reverse pairs)))])
                   #'(let* (binding ...) result))))]))


      ;;-------------------------------------------------------------------
      ;; Op form parser
      ;;-------------------------------------------------------------------

      ;; Parse one op-form into a flat list of (syntax-var . syntax-expr) pairs
      ;; that become let* bindings.
      ;;
      ;; Single-result — two pairs:
      ;;   (%r = arith.constant () ("value" = 0 :index) -> i32)
      ;;   →  [(%op-tmp-<index> . (let ([new-op (with-OperationState ...)]) new-op))
      ;;        (%r             . (mlir-Operation::getResult %op-tmp-<index> 0))]
      ;;
      ;; Multi-result — one tmp pair + one pair per result variable:
      ;;   ((%a %b) = some.op (%x) -> (t1 t2))
      ;;   →  [(%op-tmp-<index> . (let ([new-op (with-OperationState ...)]) new-op))
      ;;        (%a             . (mlir-Operation::getResult %op-tmp-<index> 0))
      ;;        (%b             . (mlir-Operation::getResult %op-tmp-<index> 1))]
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
           (let-values ([(attr-setter-fns region-fill-fns) (parse-modifiers #'(modifiers ...) builder-stx)])
             (emit-multi (syntax->list #'(var ...)) (op-name->str #'op)
                         (value-operands #'(operands ...))
                         (syntax->list #'(result-type ...)) attr-setter-fns
                         region-fill-fns index #'op builder-stx))]
          ;; Statement: no var, no ->.
          [(op (operands ...) modifiers ...)
           (op-name? #'op)
           (process-op #'(() = op (operands ...) modifiers ... -> ()) index builder-stx)]
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
      (define (parse-modifiers modifiers-stx builder-stx)
        (define (attr-name? x)
          (let ([d (syntax->datum x)])
            (or (string? d) (symbol? d))))
        (define (attr-modifier? m)
          (syntax-case m (=)
            [(name = val type) (attr-name? #'name) #t]
            [(name = val)      (attr-name? #'name) #t]
            [_ #f]))
        (define (make-region-fn m region-idx)
          (syntax-case m (:region)
            [(:region block ...)
             (for-all (lambda (b) (block-label? (car (syntax->list b))))
                      (syntax->list #'(block ...)))
             (make-region-fill-fn region-idx
                                  (map (lambda (blk)
                                         (let-values ([(builder-name arg-vars arg-types body-ops) (parse-block-form blk)])
                                           (make-block-fill-fn arg-vars arg-types body-ops builder-stx builder-name)))
                                       (syntax->list #'(block ...))))]
            ;; Shorthand: (^label ...) — normalise to (:region (^label ...)) and recurse.
            [(label . _)
             (block-label? #'label)
             (make-region-fn #`(:region #,m) region-idx)]
            [_ (syntax-violation 'begin-mlir-code "invalid modifier entry" m)]))
        (let ([result
               (loop :for m :in (syntax->list modifiers-stx)
                     :rime-with is-attr := (attr-modifier? m)
                     :collect (make-attr-setter m) :into attr-fns :if is-attr
                     :collect (make-region-fn m region-idx) :into region-fns :unless is-attr
                     :count :into region-idx :unless is-attr
                     :finally (cons attr-fns region-fns))])
          (values (car result) (cdr result))))

      ;; True when x is a block label identifier starting with ^.
      (define (block-label? x)
        (let ([datum (syntax->datum x)])
          (and (symbol? datum)
               (char=? #\^ (string-ref (symbol->string datum) 0)))))

      ;; Returns a closure (lambda (new-op-stx) → setter-syntax) for one attr form.
      ;;
      ;; Two forms:
      ;;   (name = val type)  — construct attr via (%%make-attr-by-type ctx type val)
      ;;   (name = val)       — val is already an attr uptr; set directly
      (define (make-attr-setter attr-stx)
        (define (name->str x)
          (let ([datum (syntax->datum x)])
            (if (string? datum) datum (symbol->string datum))))
        (define (make-typed-setter name-str val-stx type-quoted-stx)
          (lambda (new-op-stx)
            (with-syntax ([new-op new-op-stx] [n name-str] [v val-stx]
                          [type-q type-quoted-stx])
              #'(mlir-operation-set-attribute! new-op n
                                               (%%make-attr-by-type (mlir-Operation::getContext new-op) type-q v)))))
        (define (make-direct-setter name-str val-stx)
          (lambda (new-op-stx)
            (with-syntax ([new-op new-op-stx] [n name-str] [v val-stx])
              #'(mlir-operation-set-attribute! new-op n v))))
        (syntax-case attr-stx (=)
          [(name = val type)  (make-typed-setter  (name->str #'name) #'val #''type)]
          [(name = val)       (make-direct-setter (name->str #'name) #'val)]
          [_ (syntax-violation 'begin-mlir-code
                               "attr modifier: (name = val :type) or (name = val) for pre-built attr"
                               attr-stx)]))

      ;;-------------------------------------------------------------------
      ;; Code emitters
      ;;-------------------------------------------------------------------

      ;; Core code generator. Produces the (var . expr) pairs that become let*
      ;; bindings in the final expansion.
      ;;
      ;; Always generates a tmp binding for the Operation* itself:
      ;;   (%op-tmp-N . (let ([new-op (%%crest:create-op! builder state)])
      ;;                  setter ...           ; apply attributes
      ;;                  region-fill-stmt ... ; fill each region
      ;;                  new-op))
      ;;
      ;; Then appends one binding per result variable:
      ;;   — non-empty result-types: (%var . (mlir-Operation::getResult %op-tmp-N i))
      ;;   — empty result-types:     (%var . %op-tmp-N)  (var bound to op itself)
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
                          builder-stx)  ; syntax — the active builder expression
        (let* ([nregions (length region-fill-fns)]  ; number of region modifiers
               [op-var   (op-tmp-id index)])        ; %op-tmp-N — used for both inner and outer let
          (with-syntax
              ([operands-expr  operands]         ; runtime operand list expr
               [name           op-name]          ; string literal
               [(result-type ...) result-types]  ; result type exprs
               ;; op-var serves as BOTH the outer let* binding (%op-tmp-N)
               ;; and the inner let binding that holds the mlir::Operation*.
               ;; The inner shadows the outer within the let body — valid Scheme.
               [op              op-var]          ; inner: mlir::Operation* from create
               [op-tmp          op-var]          ; outer: %op-tmp-N exposed to callers
               [builder         builder-stx]     ; active builder
               [(setter ...)                     ; attr-setting stmts (reference op)
                (map (lambda (fn) (fn op-var)) attr-setter-fns)]
               [(region-fill-stmt ...)           ; region-filling stmts (reference op)
                (map (lambda (fn) (fn op-var)) region-fill-fns)]
               ;; Unroll N addRegion calls at expand time — nregions is compile-time.
               [(addregion-call ...)
                (loop :for i :from 0 :below nregions
                      :collect #'(mlir::OperationState::addRegion state))]
               [source-loc (syntax->mlir-loc-expr op-name-stx)])
            (cons
             ;; Binding for the Operation* itself
             (cons #'op-tmp
                   #'(let ([op
                            (let ()
                              (with-OperationState
                               (state source-loc name)
                               (for-each
                                (lambda (v) (mlir::OperationState::addOperands state v))
                                operands-expr)
                               (for-each
                                (lambda (t) (mlir::OperationState::addTypes state t))
                                (list result-type ...))
                               addregion-call ...        ; N addRegion calls, inlined
                               (%%crest:create-op! builder state)))])
                       setter ...           ; apply attributes
                       region-fill-stmt ... ; fill regions
                       op))
             ;; Bindings for result variables
             (if (null? result-types)
                 ;; Zero-result: each var bound to the op itself
                 (map (lambda (var) (cons var #'op-tmp)) result-vars)
                 ;; Multi-result: each var bound to getResult at its index
                 (loop :for var :in result-vars
                       :for i   :from 0
                       :collect #`(#,var . (mlir-Operation::getResult op-tmp #,i))))))))

      ;; Returns a closure (lambda (new-op-stx) → fill-stmt-syntax) for one region.
      ;; region-index    — 0-based index of this region within the op.
      ;; block-fill-fns  — Scheme list of block-fill closures from make-block-fill-fn.
      (define (make-region-fill-fn region-index block-fill-fns)
        (lambda (new-op-stx)
          (let ([region-id (car (generate-temporaries '(region)))])
            (with-syntax ([new-op      new-op-stx]
                          [region      region-id]
                          [region-idx  region-index]
                          [(block-fill-stmt ...)
                           (map (lambda (fn) (fn new-op-stx region-id)) block-fill-fns)])
              #'(let ([region (mlir::Operation::getRegion new-op region-idx)])
                  block-fill-stmt ...)))))

      ;; Split ((arg : type) ...) syntax into two lists: arg identifiers and types.
      (define (split-arg-types arg-type-list)
        (let ([arg-vars '()] [arg-types '()])
          (for-each (lambda (entry)
                      (let ([elems (syntax->list entry)])
                        (set! arg-vars (append arg-vars (list (list-ref elems 0))))
                        (set! arg-types (append arg-types (list (list-ref elems 2))))))
                    arg-type-list)
          (values arg-vars arg-types)))

      ;; Parse a full block stx of the form:
      ;;   (^label ((arg : type) ...) body ...)         — no builder name
      ;;   (^label builder-name ((arg : type) ...) ...) — explicit builder name
      ;; Returns (values builder-name-stx arg-vars arg-types body-ops).
      (define (parse-block-form block-stx)
        (let* ([elems  (syntax->list block-stx)]
               [second (list-ref elems 1)])
          (if (identifier? second)
              ;; (^label builder-name ((arg : type) ...) body ...)
              (let-values ([(arg-vars arg-types)
                            (split-arg-types (syntax->list (list-ref elems 2)))])
                (values second arg-vars arg-types (list-tail elems 3)))
              ;; (^label ((arg : type) ...) body ...)
              (let-values ([(arg-vars arg-types)
                            (split-arg-types (syntax->list second))])
                (values #f arg-vars arg-types (list-tail elems 2))))))

      ;; Returns a closure (lambda (new-op-stx region-stx) → block-fill-syntax).
      ;; Takes pre-extracted components — no re-parsing of syntax.
      ;;   arg-vars         — Scheme list of arg variable syntax objects
      ;;   arg-types        — Scheme list of arg type syntax objects
      ;;   body-ops         — Scheme list of body op syntax objects
      ;;   builder-name-stx — #f (builder unnamed) or a syntax identifier (user-chosen name)
      ;;
      ;; When builder-name-stx is #f, the OpBuilder is bound to a fresh gensym and
      ;; is only accessible via begin-mlir-code op-forms inside the body.
      ;; When builder-name-stx is an identifier, that name is in scope for the body,
      ;; allowing Scheme escapes to pass it to external helpers explicitly.
      (define (make-block-fill-fn arg-vars arg-types body-ops builder-stx builder-name-stx)
        (let* ([block-builder-id (if builder-name-stx
                                     builder-name-stx
                                     (car (generate-temporaries '(block-builder))))]
               [body-stx         (with-syntax ([(body ...) body-ops]
                                               [block-builder block-builder-id])
                                   #'(begin-mlir-code block-builder body ...))]
               [arg-bind-pairs   (loop :for var :in arg-vars
                                       :for i :from 0
                                       :collect #`(#,var . (mlir::Block::getArgument block #,i)))])
          (lambda (new-op-stx region-stx)
            (with-syntax ([(arg-type ...) arg-types]
                          [(arg-binding ...) (loop :for pair :in arg-bind-pairs
                                                   :collect (make-binding pair))]
                          [body              body-stx]
                          [block-builder     block-builder-id]
                          [new-op            new-op-stx]
                          [region            region-stx])
              #'(let* ([block (mlir::Region::push_back<Block> region (list arg-type ...))]
                       arg-binding ...)
                  (let ([block-builder (mlir::OpBuilder::atBlockEnd block)])
                    (dynamic-wind
                        (lambda () #f)
                        (lambda () body)
                        (lambda () (CrestObject::delete block-builder)))))))))


      ;;-------------------------------------------------------------------
      ;; Leaf helpers
      ;;-------------------------------------------------------------------

      ;; Lift a (var-stx . expr-stx) cons cell into a syntax binding (var expr).
      (define (make-binding pair)
        (with-syntax ([var (car pair)] [expr (cdr pair)]) #'(var expr)))

      ;; Accept both 'arith.constant and "arith.constant" as op names.
      (define (op-name? x)
        (let ([datum (syntax->datum x)])
          (or (string? datum) (symbol? datum))))
      (define (op-name->str x)
        (let ([datum (syntax->datum x)])
          (if (string? datum) datum (symbol->string datum))))

      ;; Build a runtime expression for the operand list from (operands ...).
      ;; Operands prefixed with ! are filtered (they are types, not values).
      ;; ,@list splices a dynamic list: (v1 ,@%more v2) → (append (list v1) %more (list v2))
      ;; All-static result: #'(list v1 v2 ...)
      ;; Any splice present: #'(append (list v1) %splice (list v2) ...)
      (define (value-operands operands-stx)
        (define (splice? x)
          (let ([d (syntax->datum x)])
            (and (pair? d) (eq? (car d) 'unquote-splicing))))
        (let ([items (filter (lambda (x) (not (type-id? x)))
                             (syntax->list operands-stx))])
          (if (for-all (lambda (x) (not (splice? x))) items)
              ;; All static — simple (list ...)
              (with-syntax ([(v ...) items]) #'(list v ...))
              ;; Mixed — build with append, grouping static runs
              (let loop ([rest items] [static-run '()] [chunks '()])
                (cond
                 [(null? rest)
                  (let ([final-chunks
                         (if (null? static-run)
                             (reverse chunks)
                             (reverse (cons (with-syntax ([(v ...) (reverse static-run)])
                                              #'(list v ...))
                                            chunks)))])
                    (with-syntax ([(chunk ...) final-chunks])
                      #'(append chunk ...)))]
                 [(splice? (car rest))
                  (let* ([splice-expr (cadr (syntax->list (car rest)))]
                         [chunks+     (if (null? static-run)
                                          (cons splice-expr chunks)
                                          (cons splice-expr
                                                (cons (with-syntax ([(v ...) (reverse static-run)])
                                                        #'(list v ...))
                                                      chunks)))])
                    (loop (cdr rest) '() chunks+))]
                 [else
                  (loop (cdr rest) (cons (car rest) static-run) chunks)])))))

      ;; True when identifier starts with ! (type convention, not a value).
      (define (type-id? x)
        (let ([datum (syntax->datum x)])
          (and (symbol? datum)
               (let ([str (symbol->string datum)])
                 (and (> (string-length str) 0)
                      (char=? #\! (string-ref str 0)))))))

      (main)))


  ) ;; end library (crest internal rewrite)
