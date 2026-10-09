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
          (for (only (crest internal keywords)
                     = : -> :region
                     :index :i64 :f32 :i32-array :i64-array :unit) expand)
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
                     mlir::OperationState::addAttribute
                     with-OperationState) expand)
          (for (only (mlir IR Location)
                     mlir::UnknownLoc::get
                     mlir::FileLineColLoc::get) expand)
          (for (only (mlir IR Region) mlir::Region::push_back<Block>) expand)
          (for (only (mlir IR Block) mlir::Block::getArgument) expand)
          (for (only (mlir IR Operation) mlir::Operation::getRegion) expand)
          (for (rename (only (mlir IR Operation)
                             mlir::Operation::getResult)
                       (mlir::Operation::getResult mlir-Operation::getResult)) expand))


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
        ;; Classify one modifier: normalise symbol/typed/shorthand forms first,
        ;; then return a tagged handler at the terminal branches.
        (define (classify m)
          (syntax-case m (= :index :i64 :f32 :i32-array :i64-array :unit :region)
            ;; Normalise and retry
            [(name = val . rest) (symbol? (syntax->datum #'name))
             (with-syntax ([str-name (datum->syntax #'name
                                                    (symbol->string (syntax->datum #'name)))])
               (classify #'(str-name = val . rest)))]
            [(name = val :index)     (classify #'(name = (mlir::IntegerAttr::get<index> val)))]
            [(name = val :i64)       (classify #'(name = (mlir::IntegerAttr::get<i64> val)))]
            [(name = val :f32)       (classify #'(name = (mlir::FloatAttr::get<f32> val)))]
            [(name = val :i32-array) (classify #'(name = (mlir::DenseI32ArrayAttr::get val)))]
            [(name = val :i64-array) (classify #'(name = (mlir::DenseI64ArrayAttr::get val)))]
            [(name = val :unit)      (classify #'(name = (mlir::UnitAttr::get)))]
            [(label . _) (block-label? #'label) (classify #`(:region #,m))]
            ;; Terminals
            [(name = val) (string? (syntax->datum #'name))
             (cons 'attr (make-direct-setter (syntax->datum #'name) #'val))]
            [(:region block ...)
             ;; All blocks must start with a label; labels start with ^.
             (for-all (lambda (b) (block-label? (car (syntax->list b))))
                      (syntax->list #'(block ...)))
             (cons 'region (lambda (idx)
                             (make-region-fill-fn idx (map make-block-fill (syntax->list #'(block ...))))))]
            [_ (syntax-violation 'begin-mlir-code "invalid modifier entry" m)]))
        ;; Split a tagged list into (values attr-fns region-fns).
        ;; Applies region indices by position in the filtered region list.
        (define (split-modifiers tagged)
          (values
           (loop :for e :in tagged :if (eq? (car e) 'attr) :collect (cdr e))
           (loop :for e :in (filter (lambda (e) (eq? (car e) 'region)) tagged)
                 :for idx :from 0
                 :collect ((cdr e) idx))))
        (define (make-block-fill blk)
          (let-values ([(builder-name arg-vars arg-types body-ops) (parse-block-form blk)])
            (make-block-fill-fn arg-vars arg-types body-ops builder-stx builder-name)))
        (define (make-region-fill-fn region-index block-fill-fns)
          (lambda (op-stx)
            (with-syntax ([new-op     op-stx]
                          [region-idx region-index]
                          [region-id  (car (generate-temporaries '(region)))]
                          [(block-fill-stmt ...)
                           (map (lambda (fn) (fn #'region-id)) block-fill-fns)])
              #'(let ([region-id (mlir::Operation::getRegion new-op region-idx)])
                  block-fill-stmt ...))))
        (define (make-direct-setter name-str val-stx)
          (lambda (state-stx)
            (with-syntax ([state state-stx] [n name-str] [v val-stx])
              #'(mlir::OperationState::addAttribute state n v))))
        (split-modifiers
         (loop :for m :in (syntax->list modifiers-stx) :collect (classify m))))

      ;; True when x is a block label identifier starting with ^.
      (define (block-label? x)
        (let ([datum (syntax->datum x)])
          (and (symbol? datum)
               (char=? #\^ (string-ref (symbol->string datum) 0)))))

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
      ;;   (%var . (mlir-Operation::getResult op-tmp i))
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
               [source-loc (syntax->mlir-loc-expr op-name-stx)])
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
                   :collect (cons var #`(mlir-Operation::getResult op-tmp #,i)))))))

      ;; Returns a closure (lambda (op-stx) → fill-stmt-syntax) for one region.
      ;; Regions are filled AFTER %%crest:create-op! via mlir::Operation::getRegion —
      ;; creating ops inside a pre-OperationState block breaks MLIR's IR invariants
      ;; (verification requires a fully linked parent-op chain).
      ;; The addRegion call in OperationState pre-allocates the slot; fill happens post-create.
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
                                       :collect (cons var #`(mlir::Block::getArgument block #,i)))])
          (lambda (region-stx)
            (with-syntax ([(arg-type ...) arg-types]
                          [(arg-binding ...) (loop :for pair :in arg-bind-pairs
                                                   :collect (make-binding pair))]
                          [body          body-stx]
                          [block-builder block-builder-id]
                          [region        region-stx])
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
