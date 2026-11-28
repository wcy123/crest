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

The four points below are about the language of the pattern, not about conversion. Each was checked in the LLVM sources and
with `mlir-pdll`, and in the CREST manual and sources.

### The rewrite is a part of a pattern in PDL, and a form of its own in CREST

- **PDL.** `pdl.rewrite` has the trait `HasParent<"pdl::PatternOp">` (`PDLOps.td`): it ends a `pdl.pattern` and exists only
  there. The PDLL manual says it too: "All PDLL rewrites must be defined within the `rewrite` section of the pattern"
  (`PDLL.md`). PDLL has named rewrites, `Rewrite BuildFooOp(value: Value) -> Op { return op<my_dialect.foo>(value); }`, that a
  pattern calls like a function, but only from a rewrite section. The code that runs a rewrite, `PDLByteCode`, is in
  `lib/Rewrite/ByteCode.h`, which is not an installed header (`include/mlir/Rewrite/` has only `FrozenRewritePatternSet.h`,
  `PassUtil.td` and `PatternApplicator.h`). There is no way to run a PDL rewrite without a match.
- **CREST.** `begin-mlir-code` emits ops with the ambient builder, and works anywhere a builder is installed: `with-current-OpBuilder`
  for a rewriter or a builder, `with-OpBuilder` to make one (`docs/manual.md` §5). The Toy samples use it where there is no
  pattern: the front end `mlir-gen.sls` builds the whole module from the AST with it, and so do the `:materialize-constant`
  hook of the dialect and the helpers of the lowerings (`%%get-or-insert-printf!` and others). With no builder it raises
  `no active builder` when it makes its first op.

### The spelling of an op

- **PDLL** writes an op in a match and in a rewrite with the same expression: `op<dialect.name>(operands) {attr = ...} ->
  (types)`. It is in the same family as the generic form, with the operands in parentheses, the attributes in braces and the
  result types after an arrow, but the pieces are wrapped (`op<...>`, `attr<"...">`, `type<"...">`), there is no region or block
  syntax, and a result is a value of a `let`, not named in the op. The IR that `mlir-pdll` writes is the `pdl` dialect:
  `%4 = operation "my.dq"(%0, %1, %2 : !pdl.value, !pdl.range<value>, !pdl.range<value>) -> (%3 : !pdl.range<type>)`.
- **CREST** writes `result = dialect.name (operands) (attr : value) { ^bb ... } -> type`, in the order of the generic form,
  with the regions as braces. The manual says it mirrors MLIR's textual format. The match (`:if-match`) uses the same
  spelling for the ops it looks for.

### Regions and attributes in a created op

- **PDL, regions.** `pdl.operation` has the fields `opName`, `operandValues`, `attributeValues` with `attributeValueNames`, and
  `typeValues`, and no region. PDLL has no syntax for a region. The bytecode that makes an op builds an `OperationState` with
  the operands, the attributes and the types, and adds no region (`ByteCode.cpp`, `executeCreateOperation`). I compiled
  `replace op<my.loop>(x: Value) with op<my.loop>(x)` for an ODS op that has a region: it compiles to a `pdl.operation` that has
  none, so an op that needs its region must be made by a native C++ rewrite. I did not run it.
- **PDL, attributes.** A constant is written `attr<"...">`, a string that `mlir-pdll` parses when it compiles the file. The
  stock `mlir-pdll` took `dense<[1.0, 2.0]> : tensor<2xf64>`, `affine_map<(d0) -> (d0)>` and `3 : i64`, and refused
  `#llvm.linkage<external>` (an attribute of the `llvm` dialect, which that tool does not load): `attribute created with
  unregistered dialect`. An attribute of a matched op can be bound and reused. A value that is computed needs a native
  rewrite.
- **CREST, regions.** `{ ... }` is one region, several braces are several regions, `^label` starts a block, a block can have
  arguments (written, or a computed list of types), and `(:move-region op)` takes the body of an existing op. The manual says
  what is missing: there is no syntax yet to branch from one block to another (`cf.br () ^exit`), so a block that no op reaches
  is dead.
- **CREST, attributes.** `(name : expr)` where `expr` is any Scheme expression that returns an `mlir::Attribute`, with
  shorthands (`:string`, `:index`, `:i32`, `:f64`, `:i64-array`, ...). The Ch6 lowering writes
  `(linkage : (mlir::parseAttribute "#llvm.linkage<external>"))`, parsed when it runs, with the dialects of its context.

### Optional and variadic operands in a match

- **PDL.** The groups come from the ODS definition of the op, so the op must be known to `mlir-pdll`. A `Variadic` operand is
  bound as a `ValueRange`. An `Optional` operand is not "variadic" for PDLL (`isVariadic()` is false for it), but a
  `ValueRange` is accepted for it: I compiled `op<my.dq>(x: Value, zp: ValueRange, rest: ValueRange)` for an op with `x`, an
  `Optional` `zp` and a `Variadic` `rest`, and it gives a range for `zp`. Written as a `Value`, the group must have exactly
  one value: the bytecode returns no match when a group asked for as one value has a different size (`ByteCode.cpp`,
  `executeGetOperandsResults`). With the groups of the ODS, the bytecode finds them in `operandSegmentSizes`, but only when
  the op has the trait `AttrSizedOperandSegments`; otherwise it assumes the range is the last group. The source says that
  `SameVariadicOperandSize` is not supported (a `FIXME`). An op that is not registered has no trait.
- **CREST.** `(:optional %zp)` binds the value when it is present and the absent value when it is not (test it with
  `unbound-value?`), and `(:variadic %inputs)` binds a list. Several groups can be next to each other. The op must carry an
  `operandSegmentSizes` attribute, and the pattern does not match without it, but the op does not have to be registered:
  CREST reads the attribute, and the hip-fusion tests run on unregistered ops (`-allow-unregistered-dialect`).

So the README's "Limited" for PDLL is fair: operand groups are there, through ODS and segment sizes, and a registered op is
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
