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
  groups, attributes and regions (the section "What the match and the rewrite can say"). The patterns were compiled to PDL,
  not run.

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
| Shared matcher | yes: the checks of many patterns are merged into one tree | no: each pattern runs its own checks, one after another |
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

Four points about the language of the pattern, not about conversion. The PDL snippets were compiled with the `mlir-pdll` of
the LLVM 23 install (compiled, not run); the CREST snippets are from `docs/manual.md` and the samples.

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
| operands | `(%a, %b)` | `(a, b)` | `(a b)` |
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

### 3. Regions and attributes in a created op

In PDL there are no regions. `pdl.operation` has these fields and no region:

**PDL: the definition in MLIR's `PDLOps.td`**
```tablegen
let arguments = (ins OptionalAttr<StrAttr>:$opName,
                     Variadic<PDL_InstOrRangeOf<PDL_Value>>:$operandValues,
                     Variadic<PDL_Attribute>:$attributeValues,
                     StrArrayAttr:$attributeValueNames,
                     Variadic<PDL_InstOrRangeOf<PDL_Type>>:$typeValues);
```

An op that has a region in ODS compiles, and the PDL has no region for it:

**PDL: PDLL**
```pdll
Pattern => replace op<my.loop>(x: Value) with op<my.loop>(x);   // my.loop has `region SizedRegion<1>:$body`
```

**PDL: the PDL IR that `mlir-pdll` writes from the PDLL above**
```mlir
%3 = operation "my.loop"(%0 : !pdl.value)      // no region; the bytecode builds an OperationState without one
```

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
the dialect of the attribute must be loaded in that context too. A `dense_resource<blob1>` is accepted as text, but the text
carries only the name, not the data (I did not run what happens to it).

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

The bytecode finds a group in `operandSegmentSizes`, if the op has the trait; asked for a single `Value`, a group of another
size is no match:

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
- A CREST pattern is a separate native pattern for each op, so there is no shared matcher.

## History

PDL had no dialect conversion before LLVM 16. Commit `8c66344ee9` (2022-11-08, D133142), "Add support for DialectConversion
with pattern configurations", added `PDLConversionConfig`, `registerConversionPDLFunctions`, the PDLL rewrites in
`DialectConversion.pdll`, and the test `test-dialect-conversion-pdll.mlir`. The upstream docs (`DialectConversion.md`,
`PDLL.md`) do not mention it, which is how it is easy to conclude that it is not supported.
