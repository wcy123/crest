# PDL and CREST for dialect conversion

MLIR's PDL (and its front end PDLL) can write patterns for a dialect conversion, and CREST can too. This page says how each
one works, with the same example, and where they differ. It is about how much of MLIR each one has to touch, and what a
user writes and waits for. It is not about speed: nothing here was measured.

What was read and run:

- The LLVM sources of `llvmorg-22.1.0` and `llvmorg-23.1.5`, and the commit history of the PDL conversion support.
- The Toy tutorial, Ch5, with `toy.print` and `toy.return` lowered by PDLL instead of C++, built against an LLVM 23
  install. Its output for 18 test programs, with and without `-opt`, is the same as the C++ version, byte for byte.
- The CREST binding, `lib/Bindings/Transforms/DialectConversion.cpp`, and the CREST manual (§5 `begin-mlir-code`, the
  operand groups of `:if-match`).
- Small PDLL files compiled with the `mlir-pdll` of the LLVM 23 install, to see what the front end accepts for operand
  groups, attributes and regions (the section "What the match and the rewrite can say"). The PDLL patterns that the text
  says are run (a region that is missing, three mistakes of type) were run in the Toy Ch5 build above, with the verifier
  of MLIR deciding; the same mistakes were made in CREST and run with `scheme-mlir`.

## In short

| | PDL / PDLL | CREST |
|---|---|---|
| Can write a dialect conversion with a `TypeConverter` | Yes, since LLVM 16 (LLVM 22 and 23 have it), when MLIR is built with `MLIR_ENABLE_PDL_IN_PATTERNMATCH` (on by default) | Yes, LLVM 22 and 23 |
| The pattern is a `ConversionPattern` | No. It is run by the same driver, but it is not a `ConversionPattern` | Yes: the C++ class is a `ConversionPattern` |
| The operands the pattern sees | the original ones; it calls `convertValue` to get the converted ones | the converted ones, always (for the root op) |
| Where the type converter comes from | a configuration object, `PDLConversionConfig`, that sets an internal field of the rewriter | the usual member of the `ConversionPattern`, and an explicit argument of the Scheme procedure |
| What MLIR had to change to support it | the pattern set, the pattern applicator, the frozen pattern set and the dialect conversion | nothing: CREST uses only public API |
| Helper functions | `convertValue`, `convertValues`, `convertType`, `convertTypes`, and a native function for any C++ logic, all registered by name | none for conversion |
| From the source to a running pattern | `.pdll` → PDL IR text → C++ string → PDL module → PDL interpreter IR → bytecode | the Scheme source is compiled when its library loads |
| After an edit | rebuild | run again (development mode) |
| When a mistake shows | many at build time; a missing helper at run time | at the first run, when the library is imported |
| The checks of many patterns | merged into one matcher tree | not merged: each pattern runs its own checks, one after another; patterns can share source with a macro or a function |
| Build IR outside a pattern | no: a PDL rewrite exists only inside a `pdl.pattern` | yes: `begin-mlir-code` works in any Scheme code with a builder |
| Spelling of a created op | `op<name>(operands) {attrs} -> (types)`, similar to the generic form, with no regions | `r = name (operands) (attr : value) { ^bb ... } -> type`, regions included |
| Regions and arbitrary attributes in a created op | no regions; attributes written as `attr<"...">` text, from the dialects `mlir-pdll` knows, or computed in a native C++ rewrite | regions with blocks and arguments; an attribute is any Scheme expression |
| Optional and variadic operands in a match | yes, through the ODS definition of a registered op and its `operandSegmentSizes` | yes, `(:optional %x)` and `(:variadic %xs)`, with `operandSegmentSizes` on the op, registered or not |

## The example: `toy.print` in Toy Ch5

`toy.print` is not lowered in Ch5, but its operand changes from a tensor to a `memref`, so the op must be made again with the
converted operand. The target says `toy.print` is legal only when its operand is not a tensor.

### With PDLL

```
Pattern PrintOpLowering => replace op<toy.print>(input: Value)
                           with op<toy.print>(convertValue(input));
```

The pass builds its pattern set once, in `initialize`:

```cpp
RewritePatternSet patternList(context);
patternList.add<AddOpLowering, ConstantOpLowering, FuncOpLowering,
                MulOpLowering, TransposeOpLowering>(context);
registerConversionPDLFunctions(patternList);
populateGeneratedPDLLPatterns(patternList, PDLConversionConfig(/*converter=*/nullptr));
patterns = std::move(patternList);          // a FrozenRewritePatternSet
```

What the driver does with it (`DialectConversion.cpp`, `PatternApplicator.cpp`):

```
legalize(toy.print %t):                          # %t is a tensor, already replaced by a memref
  bytecode.match(op)                             # runs on the original op: input is %t
  bytecode.rewrite(rewriter, match):
      config.notifyRewriteBegin(rewriter)        # rewriterImpl.currentTypeConverter = &converter
      x2 = convertValue(input)                   # rewriter.getRemappedValue -> impl.remapValues
      replace the op with: toy.print(x2)
      config.notifyRewriteEnd(rewriter)          # currentTypeConverter = nullptr
  the new toy.print has a memref operand: legal
```

`toy.return` has no operand to convert: `Pattern ReturnOpLowering => replace op<toy.return>() with op<func.return>();`. The
empty parentheses matter. The generated PDL then has no `operands` value, and PDL checks for exactly zero operands
(`PredicateTree.cpp`), as the C++ `hasOperand()` check does. `op<toy.return>` without parentheses leaves the operands free.

If the pattern is not added, the conversion fails with `failed to legalize operation 'toy.print'`. If `convertValue(input)`
is written as `input`, it fails the same way: the framework does not convert the operand of a PDL pattern. If
`registerConversionPDLFunctions` is forgotten, `toyc-ch5` crashes with a segmentation fault and no message.

### With CREST

```scheme
(define-conversion-pattern (%%print-lower! op operands-ref rw tc)
  :if-match
    toy.print (%in)
  :rewrite op :with
    toy.print (%in))
```

`:if-match` sets `%in` from `operands-ref`, index 0 (the macro writes that code), and `operands-ref` holds the converted
operands. The rewrite makes the new `toy.print` with `%in`. Nothing is registered by name.

## Why PDL needs a side channel

A native conversion pattern gets its operands as an argument. `ConversionPattern::matchAndRewrite(op, rewriter)` is `final`:
it sets `currentTypeConverter` from the pattern, remaps the operands with `remapValues`, and calls the function you override,
`matchAndRewrite(op, operands, rewriter)` (the adaptor form in `OpConversionPattern`).

A PDL pattern is not a `ConversionPattern`. `PDLByteCodePattern` derives from the bare `Pattern` (`lib/Rewrite/ByteCode.h`),
and `PatternApplicator` runs a PDL match with `bytecode->rewrite(...)`. Neither `matchAndRewrite` is called. So MLIR added:

- `PDLConversionConfig`, whose hooks set and clear `currentTypeConverter` through `rewriter.getImpl()`. `getImpl()` is
  declared public, but `ConversionPatternRewriterImpl` is defined only in `DialectConversion.cpp`, where this code lives.
- The functions `convertValue(s)` and `convertType(s)`, which the pattern must call itself. They use the public
  `ConversionPatternRewriter::getRemappedValue(s)`, and `convertType` reads `currentTypeConverter`.

`convertValue` goes through `static_cast<ConversionPatternRewriter &>`, which is right only because the conversion driver runs
it. `getRemappedValues` asserts on a 1:N conversion (`DialectConversion.cpp:2265`).

Since it is not a `ConversionPattern`, a PDL pattern also has no `getTypeConverter()` and no `OpAdaptor`. A pattern that does
not call `convertValue` sees the original operands.

## How CREST does it

`SchemeConversionPattern` (`lib/Bindings/Transforms/DialectConversion.cpp`) is a `mlir::ConversionPattern`. With a type
converter it is built with `ConversionPattern(*typeConverter, opName, benefit, ctx)`. Its `matchAndRewrite(op, operands,
rewriter)` calls the Scheme procedure with `op`, the remapped operands, a handle of the rewriter, and a handle of the type
converter. The framework has already set `currentTypeConverter` and remapped the operands, as for any native pattern.
Without a converter (`:no-type-converter`) the second constructor is used and `0` is passed.

CREST uses no private MLIR API, and no change to MLIR was needed. The cost is a dependence on the shape of the public
`ConversionPattern`: the binding overrides the `ArrayRef<Value>` form, and MLIR also has a 1:N form,
`ArrayRef<ValueRange>`.

## What the match and the rewrite can say

Each code block has a label above it. **PDL** is PDLL (the language of a pattern), the PDL IR that `mlir-pdll` writes from it,
and MLIR's own PDL code. **CREST** is the Scheme DSL. **MLIR** is MLIR's textual generic form, shown as the reference. A CREST
snippet whose lines look like `%c = arith.constant ...` is the body of a `begin-mlir-code` form, shown without the wrapper: those
lines are op-forms of the DSL, not Scheme expressions by themselves.

Four points about the language of the pattern, not about conversion. Every PDL snippet was compiled with the `mlir-pdll` of the
LLVM 23 install; where the text shows an error of `toyc-ch5` or of `scheme-mlir`, the pattern was also run. The CREST snippets
are from `docs/manual.md` and the samples.

### 1. A rewrite outside a pattern

In PDL a rewrite exists only inside a pattern.

**PDL: the definition in MLIR's `PDLOps.td`**
```tablegen
// PDLOps.td
def PDL_RewriteOp : PDL_Op<"rewrite", [
     Terminator, HasParent<"pdl::PatternOp">, NoTerminator, NoRegionArguments,
     SingleBlock, AttrSizedOperandSegments, ...
```

**PDL: PDLL, the language of a pattern**
```pdll
// PDLL: a named rewrite is a function, but a pattern's rewrite section is the only caller
Rewrite BuildFooOp(value: Value) -> Op {
  return op<my_dialect.foo>(value);
}
Pattern {
  replace op<my_dialect.old_op>(input: Value) with BuildFooOp(input);
}
```

PDLL.md: "All PDLL rewrites must be defined within the `rewrite` section of the pattern". The code that runs a rewrite is
`lib/Rewrite/ByteCode.h`, which is not an installed header.

In CREST `begin-mlir-code` works wherever a builder is installed. This is the Toy front end, with no pattern anywhere:

**CREST: the Toy front end**
```scheme
(define (%%mlir-gen-literal expr)
  (let* ([loc   (%%loc (literal-expr:loc expr))]
         [dims  (literal-expr:dims expr)]
         [data  (%%collect-data expr)]
         [type  (mlir::RankedTensorType::get dims (mlir::Float64Type::get))]
         [attr  (mlir::DenseElementsAttr::get<f64> type data)])
    (begin-mlir-code
        r = toy.constant () (value : attr) :loc loc)))
```

This is a dialect hook, called by MLIR when a fold returns an attribute (the struct case of Ch7 is left out here):

**CREST: a dialect hook**
```scheme
(:materialize-constant (builder value type loc)
  (with-current-OpBuilder builder
    (mlir::Value::getDefiningOp
     (begin-mlir-code
         r = toy.constant () (value : value) :loc loc -> type))))
```

Outside a pattern you install the builder yourself: `(with-current-OpBuilder b ...)`, or `(with-OpBuilder b (mlir::OpBuilder::atBlockEnd block) ...)`
to make one. With none, `begin-mlir-code` raises `no active builder` at its first op.

### 2. How an op is spelled

The same op written four ways: MLIR's generic form, PDLL, the PDL IR that `mlir-pdll` writes from the PDLL, and CREST.

#### An op with no operand: `arith.constant`

**MLIR: generic form**
```mlir
%c = "arith.constant"() <{value = 42 : index}> : () -> index
```

**PDL: PDLL**
```pdll
op<arith.constant> {value = attr<"42 : index">} -> (type<"index">)
```

**CREST**
```scheme
%c = arith.constant () (value : 42 :index) -> idx    ; idx: a Scheme variable whose value is an mlir::Type
```

#### An op with operands and an attribute: `arith.cmpi`

**MLIR: generic form**
```mlir
%r = "arith.cmpi"(%a, %b) <{predicate = 2 : i64}> : (i32, i32) -> i1
```

**PDL: PDLL**
```pdll
op<arith.cmpi>(a, b) {predicate = attr<"2 : i64">} -> (type<"i1">)
```

**PDL: the PDL IR that `mlir-pdll` writes from the PDLL above**
```mlir
%4 = attribute = 2 : i64
%5 = type : i1
%6 = operation "arith.cmpi"(%0, %1 : !pdl.value, !pdl.value) {"predicate" = %4} -> (%5 : !pdl.type)
```

**CREST**
```scheme
%r = arith.cmpi (%a %b) (predicate : 2 :i64) -> bool-ty    ; bool-ty: a Scheme variable whose value is an mlir::Type
%s = arith.addi (%a %b) -> ty                              ; ty: the same, e.g. the value of (mlir::Value::getType %a)
```

In `-> idx`, `idx` is not a keyword. It is a normal Scheme variable whose value is an `mlir::Type`, for example from
`(define idx (mlir::IndexType::get))`, so any type can be written there: a type made by a call, the type of an existing
value, a tensor type, a type that was computed (the manual, "Result types"). A result variable can be written with or
without the `%`; the Toy samples write it without.

#### An op with a region: `scf.for`

**MLIR: generic form**
```mlir
"scf.for"(%lb, %ub, %st) ({
^bb0(%iv: index):
  "scf.yield"() : () -> ()
}) : (index, index, index) -> ()
```

**PDL: PDLL**
```pdll
// no spelling: PDLL has no syntax for a region (point 3)
```

**CREST: the Ch6 lowering of `toy.print`**
```scheme
;; from the Ch6 lowering of toy.print: Scheme code runs inside the body
scf.for (lb ub st)
{ ^body ((iv : idx))
  (nest (cdr dims) (cons iv ivs))
  (when (pair? (cdr dims))
    (%%call-printf! loc ctx printf-ref (list nl)))
  scf.yield () :loc loc }
:loc loc
```

#### What each one writes

| | generic form | PDLL | CREST |
|---|---|---|---|
| operands | `(%a, %b)` | `(a, b)` | `(%a %b)` |
| attributes | `<{name = value}>` | `{name = attr<"text">}` for a constant, a bound `v`, or a native rewrite | `(name : expr)`, any expression |
| result types | `: (operand types) -> type` | `-> (type<"i1">)`, a type written as text | `-> ty`, `ty` a Scheme variable holding any `mlir::Type` |
| regions | `({ ^bb0(%iv: index): ... })` | none | `{ ^body ((iv : idx)) ... }` |
| the result | `%r =` | a `let` variable | `r =` |
| the match | not applicable | the same expression | the same spelling, in `:if-match` |

PDLL is in the same family as the generic form: the operands in parentheses, the attributes in braces, the result types after an
arrow. It wraps the pieces (`op<...>`, `attr<"...">`, `type<"...">`), a result is the value of a `let` and not named in the op,
and a region cannot be written. The attribute and the type are text in a string, `"42 : index"` and `"index"`: the MLIR syntax
for an attribute and a type, a second language inside PDLL (point 3). CREST follows the generic form in the order of the pieces
and the braces of a region, and an attribute, a type and an operand are Scheme expressions, not text.

#### What the PDL types check

`!pdl.value` and `!pdl.type` in the PDL IR (`Value` and `Type` in PDLL) are kinds: a value, a type, an attribute, an operation,
or a range of them. They are not MLIR types. Every operand of every `pdl.operation` prints as `!pdl.value`, whatever its type,
so, unlike the generic form (`: (i32, i32) -> i1`), the PDL IR says nothing about the MLIR types. I tried four mistakes with
`mlir-pdll`, on an op whose ODS says that its operands are signless integers of the same type and that its result is `i1`:

**PDL: PDLL, with what `mlir-pdll` does**
```pdll
op<my.cmp>(a, type<"i32">) -> (type<"i1">)                      // error: unable to convert expression of type `Type` to the expected type of `Value`
op<my.cmp>(a, b) -> (type<"f32">)                               // compiles, but the ODS result is I1
op<my.cmp>(a: Value<type<"i32">>, b: Value<type<"i64">>) ...    // compiles, but the op is SameTypeOperands
op<my.cmp>(a: Value<type<"f32">>, b: Value<type<"f32">>) ...    // compiles, but the ODS operands are AnySignlessInteger
```

So the kind is checked when `mlir-pdll` compiles the file, and the type constraints of ODS are not. They are checked by the
verifier of the op. The same three mistakes, written with `arith.cmpi` (its verifier checks the operands and the result), in a
PDLL pattern that replaces the `toy.print` of `print.toy` in the Toy Ch5 build:

**PDL: PDLL**
```pdll
op<arith.cmpi>(a, a) {predicate = attr<"2 : i64">} -> (type<"f32">)     // a is an i32 constant: the result must be i1
op<arith.cmpi>(a, b) {predicate = attr<"2 : i64">} -> (type<"i1">)      // a is an i32 constant, b an i64 one
op<arith.cmpi>(a, a) {predicate = attr<"2 : i64">} -> (type<"i1">)      // a is an f32 constant
```

**PDL: what `toyc-ch5` prints for each pattern (exit status 4)**
```
print.toy:3:3: error: 'arith.cmpi' op result #0 must be bool-like, but got 'f32'
print.toy:3:3: error: 'arith.cmpi' op requires all operands to have the same type
print.toy:3:3: error: 'arith.cmpi' op operand #0 must be signless-non-zero-bitwidth-integer-like, but got 'f32'
```

In CREST a wrong kind is a Scheme error when the op is built, and the three type mistakes are built and left to the verifier too:

**CREST: a wrong kind**
```scheme
%c = arith.constant () (value : 42 :index) -> "not a type"     ; Scheme error: invalid foreign-procedure argument ("not a type")
```

**CREST: the same three type mistakes, then `(mlir::Operation::verify? module)`**
```scheme
%r = arith.cmpi (%a %a) (predicate : 2 :i64) -> f32            ; a is an i32 constant
%r = arith.cmpi (%a %b) (predicate : 2 :i64) -> i1             ; a is an i32 constant, b an i64 one
%r = arith.cmpi (%a %a) (predicate : 2 :i64) -> i1             ; a is an f32 constant
```

**CREST: what `scheme-mlir` prints for each (`verify?` returns `#f`)**
```
loc("c1.sls":29:26): error: 'arith.cmpi' op result #0 must be bool-like, but got 'f32'
loc("c2.sls":30:26): error: 'arith.cmpi' op requires all operands to have the same type
loc("c3.sls":29:26): error: 'arith.cmpi' op operand #0 must be signless-non-zero-bitwidth-integer-like, but got 'f32'
```

Both build the op and let the verifier judge, with the same three messages. The location differs: the PDL error is at the Toy op
that was replaced (`print.toy:3:3`), and the CREST error is, by default, at the line of the op-form in the `.sls` file (`:loc`
overrides it). The error for a wrong kind in CREST has a message about a foreign procedure, not about the op.

### 3. Regions and attributes in a created op

PDL cannot add a region. There is nothing to write: `pdl.operation`, the op that creates an op, has these fields and no region:

**PDL: the definition in MLIR's `PDLOps.td`**
```tablegen
let arguments = (ins OptionalAttr<StrAttr>:$opName,
                     Variadic<PDL_InstOrRangeOf<PDL_Value>>:$operandValues,
                     Variadic<PDL_Attribute>:$attributeValues,
                     StrArrayAttr:$attributeValueNames,
                     Variadic<PDL_InstOrRangeOf<PDL_Type>>:$typeValues);
```

The other ops of the `pdl` dialect (`pattern`, `operand`, `operands`, `attribute`, `type`, `types`, `result`, `results`, `range`,
`replace`, `erase`, `rewrite`, `apply_native_constraint`, `apply_native_rewrite`) have none that makes a region or moves one.

The pattern below does not add a region. It is here to show what happens when an op that has one in ODS is created: PDLL
accepts it, and the new op has no body. There is no place in the syntax to write one.

**PDL: PDLL**
```pdll
// my.loop has `region SizedRegion<1>:$body` in ODS. The new my.loop gets no body:
Pattern => replace op<my.loop>(x: Value) with op<my.loop>(x);
```

**PDL: the PDL IR that `mlir-pdll` writes from the PDLL above**
```mlir
%3 = operation "my.loop"(%0 : !pdl.value)      // no region: the bytecode builds an OperationState without one
```

The way to get an op with a region is C++. A native rewrite creates the op and its body, and the pattern only calls it:

**PDL: PDLL**
```pdll
Rewrite BuildLoop(x: Value) -> Op;      // written in C++ and registered by name: it creates my.loop and fills in its body
Pattern => replace op<my.loop>(x: Value) with BuildLoop(x);
```

**PDL: the PDL IR that `mlir-pdll` writes from the PDLL above**
```mlir
%3 = apply_native_rewrite "BuildLoop"(%0 : !pdl.value) : !pdl.operation
```

What a missing region does, run in the Toy Ch5 build: a PDLL pattern that replaces the `toy.print` of `print.toy` with an
`affine.for` that has all its attributes and no region.

**PDL: PDLL**
```pdll
Pattern MakeLoop with benefit(10) => replace op<toy.print>(input: Value)
    with op<affine.for> {lowerBoundMap = attr<"affine_map<() -> (0)>">,
                         upperBoundMap = attr<"affine_map<() -> (4)>">,
                         step = attr<"1 : index">,
                         operandSegmentSizes = attr<"array<i32: 0, 0, 0>">};
```

**PDL: what `toyc-ch5` prints (exit status 4)**
```
print.toy:3:3: error: 'affine.for' op requires one region
print.toy:3:3: note: see current operation: "affine.for"() <{lowerBoundMap = affine_map<() -> (0)>, operandSegmentSizes = array<i32: 0, 0, 0>, step = 1 : index, upperBoundMap = affine_map<() -> (4)>}> : () -> ()
```

The pattern runs, the op is created with no region, and the verifier rejects it. The C++ function `BuildLoop` of the previous
pattern is not part of this page.

In CREST there is one brace for each region, `^label` for a block, block arguments written or computed, `:move-region` to
keep a body:

**CREST**
```scheme
op = scf.if (%cond)
     { a = my.compute_a (%x) -> !i32
       scf.yield (%a) }
     { b = my.compute_b (%y) -> !i32
       scf.yield (%b) }
     -> !i32

func.func ()
  (sym_name : (mlir::Operation::getAttr op "sym_name"))
  (:move-region op)
```

Limit: there is no syntax yet to branch from one block to another (`cf.br () ^exit`).

In PDL an attribute constant is text, parsed by `mlir-pdll` when it compiles the file.

**PDL: PDLL**
```pdll
op<foo.b> {value = attr<"dense<[1.0, 2.0]> : tensor<2xf64>">}        // accepted
op<foo.b> {map   = attr<"affine_map<(d0) -> (d0)>">}                 // accepted
op<foo.b> {linkage = attr<"#llvm.linkage<external>">}                // refused by the stock mlir-pdll:
```

The text in `attr<"...">` and `type<"...">` is another language inside a string: the MLIR attribute and type syntax. `mlir-pdll`
parses it as a separate source, so a mistake in it is reported at a place inside the string (the string is the file name), not
in the `.pdll` file:

**PDL: the errors of `mlir-pdll` for a mistake inside the string**
```
attr<"42 :: index">                 loc("42 :: index":1:5): error: expected non-function type
attr<"#llvm.linkage<external>">     loc("#llvm.linkage<external>":1:7): error: #"llvm"<"linkage<external>"> : 'none' attribute created with unregistered dialect. If this is intended, ...
type<"indx">                        loc("indx":1:1): error: expected non-function type
```

After `mlir-pdll` the string is gone: the PDL IR has a real attribute (`%4 = attribute = 2 : i64`, point 2). CREST can write the same
text, `(mlir::parseAttribute "#llvm.linkage<external>")` in the Ch6 lowering below, but that is for an attribute that has no
shorthand: the usual form is a value, `(value : 42 :index)`.

So text covers only the attributes that can be spelled in a pattern. Any attribute can still reach a PDL rewrite, because a
`pdl.attribute` holds an `mlir::Attribute` (`OptionalAttr<AnyAttr>:$value` in `PDLOps.td`). It does not come from the text, but
from the matched IR or from C++:

**PDL: PDLL, the three sources of an attribute**
```pdll
// 1. a constant, as text: only what the MLIR syntax can spell, from the dialects mlir-pdll knows
Pattern => replace op<foo.a> with op<foo.b> {value = attr<"42 : index">};

// 2. bound from the matched op: any attribute, with no text
Pattern => replace op<foo.a> {value = v: Attr} with op<foo.b> {value = v};

// 3. computed: a native rewrite, written in C++ and registered by name (registerRewriteFunction)
Rewrite ScaleAttr(a: Attr) -> Attr;
Pattern => replace op<foo.a> {value = v: Attr} with op<foo.b> {value = ScaleAttr(v)};
```

So the answer to "can PDL write an arbitrary attribute?" is yes for 2 and 3, and no for 1. An attribute that has to be built from
values of the match, or that has no text in the dialects `mlir-pdll` loads, needs C++ (or the matched IR). A constant that is
text has one more limit: the generated header keeps the PDL IR as text and parses it again at run time (`parseSourceString`), so
the dialect of the attribute must be loaded in that context too. A `dense_resource<blob1>` is accepted: the PDL IR text parses again and prints back as
`dense_resource<blob1> : tensor<2xf32>`, with no resource section, so no data travels with it.

In CREST an attribute is any Scheme expression that returns an `mlir::Attribute`, or a shorthand. This is the Ch6 lowering:

**CREST: the Ch6 lowering**
```scheme
llvm.func ()
  (sym_name : "printf" :string)
  (function_type : (mlir::TypeAttr::get fnty))
  (linkage : (mlir::parseAttribute "#llvm.linkage<external>"))
  (CConv : (mlir::parseAttribute "#llvm.cconv<ccc>"))
  { }
```

### 4. Optional and variadic operands in a match

The op, in ODS, with a required, an optional and a variadic operand (the shape of `hip.dequantize_linear`):

**Both: the ODS definition of the op**
```tablegen
def DQOp : My_Op<"dq", [AttrSizedOperandSegments]> {
  let arguments = (ins AnyType:$x, Optional<AnyType>:$zp, Variadic<AnyType>:$rest);
  let results = (outs AnyType:$out);
}
```

In PDL the groups come from the ODS definition, so the op must be known to `mlir-pdll`.

**PDL: PDLL**
```pdll
op<my.dq>(x: Value, zp: ValueRange, rest: ValueRange)    // compiles: zp is a range of 0 or 1
op<my.dq>(x: Value, zp: Value,      rest: ValueRange)    // compiles: zp must have exactly one value
op<my.dq>(x: Value, rest: ValueRange)                    // error: invalid number of operand groups for `my.dq`; expected 3, but got 2
```

The bytecode finds a group in `operandSegmentSizes`, if the op has the trait. Asked for a single `Value`, it returns a null
pointer when the group does not have exactly one value:

**PDL: MLIR's own code, `ByteCode.cpp`**
```cpp
// ByteCode.cpp, executeGetOperandsResults (attrSizedSegments is "operandSegmentSizes" for operands)
} else if (op->hasTrait<AttrSizedSegmentsT>()) {            // needs the trait: a registered op
  auto segmentAttr = op->getAttrOfType<DenseI32ArrayAttr>(attrSizedSegments);
  ...
// FIXME: We currently don't support operations with
// SameVariadicOperandSize/SameVariadicResultSize here ...
...
return values.size() != 1 ? nullptr : values.front().getAsOpaquePointer();   // asked for one Value
```

In CREST `(:optional ...)` and `(:variadic ...)` go in the operand list. The op needs an `operandSegmentSizes` attribute, but not
a registration (the hip-fusion tests run with `-allow-unregistered-dialect`).

**CREST**
```scheme
%dq = hip.dequantize_linear (%ctx %x %scale (:optional %zp) %init)
:then-let ([zp (if (unbound-value? %zp) 0 (extract-zp %zp))])      ; absent: %zp is the absent value

%op = my.op (%x (:optional %y) (:variadic %z))                     ; required, optional, variadic; %z is a Scheme list
%op = my.op (%x (:optional %a %b) %y)                              ; two optional slots
```

The README's "Limited" for PDLL is fair: the groups are there, through ODS and the segment sizes, and a registered op is
needed to use them fully.

## What the PDL path costs, and what it gives

In MLIR:

- The pattern set, `PatternApplicator`, `FrozenRewritePatternSet` and the dialect conversion each have PDL code
  (`PatternMatch.h` holds a PDL member, a constructor, and `add` and `insert` overloads for it). It all sits behind
  `MLIR_ENABLE_PDL_IN_PATTERNMATCH`; with the option off the header has stub classes.

For a user:

- **The tool chain.** `mlir-pdll -x=cpp` writes `ToyLowering.h.inc` with the pattern as PDL IR text in a C++ string. At run
  time the generated constructor parses that text (`parseSourceString`), then `FrozenRewritePatternSet` converts the module to
  PDL interpreter IR (`convertPDLToPDLInterp`) and builds the bytecode (`PDLByteCode`). The `pdl` and `pdl_interp` dialects
  must be loaded for this.
- **Names that must match.** The `.pdll` declares `convertValue`, and C++ registers `"convertValue"`. Nothing checks that the two
  agree before the pattern runs. Only a missing registration was tried (a crash); a misspelled name was not.
- **More helpers.** Any condition PDLL cannot say, and any rewrite that is not "replace with an op", is a native C++ function
  registered the same way. In the Ch5 experiment only two of the seven patterns (`toy.print` and `toy.return`) could be
  PDLL alone. The other five build loop nests or move a region.
- **What it gives in return.** MLIR merges the checks of many PDL patterns into one matcher tree (predicate tree merging).
  CREST runs the checks of each pattern in Scheme, one after another, and gives up that sharing. This was not measured.

## What CREST gives up

- A mistake in a CREST pattern is found at the first import, not at build time (README, "What you give up").
- Edit and run needs development mode. In boot mode the `.sls` files are inside the binary and a change needs a rebuild.
- **The merged matcher: when several patterns share a check, PDL does it once, and CREST does it once for each pattern.**

The example is four PDLL patterns. P1 and P3 both match a `foo.root` with two operands, so they share every check:

**PDL: PDLL, four patterns**
```pdll
Pattern P1 => replace op<foo.root>(a: Value, b: Value) with a;              // P1 and P3: the same match
Pattern P2 => replace op<foo.root>(a: Value, b: Value, c: Value) with b;
Pattern P3 => replace op<foo.root>(a: Value, b: Value) with b;              // P1 and P3: the same match
Pattern P4 => replace op<foo.other>(a: Value) with a;
```

PDL turns them into one matcher. The checks are done once, and the tree splits only where the patterns differ:

**PDL: the one matcher that MLIR builds from them (`pdl_interp`, shortened)**
```
switch_operation_name of %root to ["foo.root", "foo.other"]      // the op name: once, for all four patterns
  foo.root:
    switch_operand_count of %root to [2, 3]                      // the operand count: once, for P1, P2 and P3
      2: get_operand 0, is_not_null; get_operand 1, is_not_null  // the two operands: once, for P1 and P3
         record_match P3 ; record_match P1                       // only here do P1 and P3 part
      3: get_operand 0..2, is_not_null; record_match P2
  foo.other:
    check_operand_count is 1; get_operand 0; record_match P4
```

This is the output of `mlir-pdll -x=mlir` followed by `mlir-opt -convert-pdl-to-pdl-interp`.

**CREST does not share them.** MLIR still chooses the patterns of an op by the root op name they are registered with
(`("demo.a" rename-a 1)`). After that, each pattern runs its own checks in Scheme. The generated code of a pattern compares the op
name again, checks the result count and reads its operands from `operands-ref` (the expansion of the `toy.print` pattern shows it).
P1 and P3 written in CREST would each do that work.

## Sharing the source of patterns

The patterns of CREST can share their source, with a Scheme function or a macro. This macro defines two patterns from one
template (run with `crest-opt`: `demo.a` becomes `demo.a2` and `demo.b` becomes `demo.b2`):

**CREST: two patterns from one macro**
```scheme
(define-syntax define-rename
  (syntax-rules ()
    [(_ name from to)
     (define-rewrite-pattern (name op rewriter)
       :if-match
         %out = from (%x)
       :then-let
         ([!t (mlir::Value::getType %out)])
       :rewrite %out :with
         r = to (%x) -> !t)]))

(define-rename rename-a demo.a demo.a2)
(define-rename rename-b demo.b demo.b2)

(apply-patterns module-op ctx :patterns (("demo.a" rename-a 1)
                                         ("demo.b" rename-b 1)))
```

The macro shares the text of the pattern. At run time there are still two patterns, each with its own checks, so this does not
give back the merged matcher of the previous section.
