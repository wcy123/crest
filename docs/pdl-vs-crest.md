# PDL and CREST for dialect conversion

MLIR has a pattern language, PDL (written in its front end, PDLL), and CREST is a Scheme DSL for patterns. Both can write the
patterns of a dialect conversion. This page shows how each one does it, with the same example, and where they differ. It is about
how much each one has to touch in MLIR, and what a user writes and waits for. Nothing here was measured for speed.

How this was checked:

- The LLVM sources of `llvmorg-22.1.0` and `llvmorg-23.1.5`, and the history of the PDL conversion support.
- The Toy tutorial, Ch5, built against an LLVM 23 install, with `toy.print` and `toy.return` lowered by PDLL instead of C++. For
  18 test programs, with and without `-opt`, the output is the same as the C++ version.
- Small PDLL files compiled with the `mlir-pdll` of that install, and the same mistakes made in CREST and run with `scheme-mlir`.
  Where a block shows an error message, that program was run.
- The CREST binding `lib/Bindings/Transforms/DialectConversion.cpp` and the CREST manual.

## In short

| | PDL (PDLL) | CREST |
|---|---|---|
| Dialect conversion with a `TypeConverter` | yes, since LLVM 16 (so in 22 and 23), when MLIR is built with `MLIR_ENABLE_PDL_IN_PATTERNMATCH` (on by default) | yes, in 22 and 23 |
| The pattern is a `ConversionPattern` | no: the same driver runs it, but its class is not a `ConversionPattern` | yes |
| The operands the pattern sees | the original ones; it calls `convertValue` to get the converted ones | the converted ones (for the root op) |
| Where the type converter comes from | `PDLConversionConfig`, which sets a field inside the rewriter | the usual member of the `ConversionPattern`; also an argument of the Scheme procedure |
| What MLIR had to change | the pattern set, the pattern applicator, the frozen pattern set and the dialect conversion | nothing: CREST uses only public API |
| Helper functions | `convertValue`, `convertValues`, `convertType`, `convertTypes`; each piece of C++ logic is one more, registered by name | none for conversion |
| From the source to a running pattern | `.pdll` → PDL IR text in a C++ string → PDL module → PDL interpreter IR → bytecode | the Scheme source is compiled when its library loads |
| After an edit | rebuild | run again (development mode) |
| Where mistakes show | many at build time; a missing helper at run time | at the first run, when the library is imported |
| A rewrite outside a pattern | not possible | possible |
| Regions in a created op | not possible; needs a C++ function | written with braces |
| Attributes in a created op | text, a value taken from the match, or a C++ function | any Scheme expression |
| Optional and variadic operands in a match | yes, for a registered op, through ODS and `operandSegmentSizes` | yes, with `operandSegmentSizes` on the op, registered or not |

## 1. The example: `toy.print` in Toy Ch5

Ch5 does not lower `toy.print`, but its operand changes from a tensor to a `memref`, so the op must be made again with the converted
operand. The conversion target says `toy.print` is legal only when its operand is not a tensor.

### In PDLL

```pdll
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

What the driver does for one `toy.print` (`DialectConversion.cpp`, `PatternApplicator.cpp`):

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

Three ways to get it wrong, all tried:

- The pattern is not added: the conversion fails with `failed to legalize operation 'toy.print'`.
- `convertValue(input)` is written as `input`: it fails the same way, because nothing converts the operand of a PDL pattern.
- `registerConversionPDLFunctions` is forgotten: `toyc-ch5` crashes with a segmentation fault and no message.

`toy.return` has no operand to convert: `Pattern ReturnOpLowering => replace op<toy.return>() with op<func.return>();`. The empty
parentheses matter. They make PDL test for exactly zero operands (`PredicateTree.cpp`), as the C++ `hasOperand()` check does.
`op<toy.return>` without parentheses leaves the operands free.

### In CREST

```scheme
(define-conversion-pattern (%%print-lower! op operands-ref rw tc)
  :if-match
    toy.print (%in)
  :rewrite op :with
    toy.print (%in))
```

`:if-match` sets `%in` from index 0 of `operands-ref`; the macro writes that code. `operands-ref` holds the converted operands. The
rewrite makes the new `toy.print` with `%in`. Nothing is registered by name.

## 2. Why PDL needs extra helpers

A native conversion pattern gets its operands as an argument. `ConversionPattern::matchAndRewrite(op, rewriter)` is `final`. Before
it calls your code, it sets `currentTypeConverter` from the pattern and converts the operands with `remapValues`. Your
`matchAndRewrite(op, operands, rewriter)` (the adaptor form in `OpConversionPattern`) receives the result.

A PDL pattern is not a `ConversionPattern`. `PDLByteCodePattern` derives from the bare `Pattern` (`lib/Rewrite/ByteCode.h`), and
`PatternApplicator` runs a PDL match with `bytecode->rewrite(...)`. Neither `matchAndRewrite` is called. So MLIR added two things:

- `PDLConversionConfig`. Its hooks set and clear `currentTypeConverter` through `rewriter.getImpl()`. (`getImpl()` is public, but
  `ConversionPatternRewriterImpl` is defined only in `DialectConversion.cpp`, where this code lives.)
- `convertValue(s)` and `convertType(s)`, which the pattern must call itself. They use the public
  `ConversionPatternRewriter::getRemappedValue(s)`, and `convertType` reads `currentTypeConverter`.

Three things follow:

- A PDL pattern has no `getTypeConverter()` and no `OpAdaptor`. If it does not call `convertValue`, it sees the original operands.
- `convertValue` casts the rewriter to `ConversionPatternRewriter`. That is right only because the conversion driver runs it.
- `getRemappedValues` asserts on a 1:N conversion (`DialectConversion.cpp:2265`).

## 3. How CREST does it

`SchemeConversionPattern` (`lib/Bindings/Transforms/DialectConversion.cpp`) is a `mlir::ConversionPattern`. With a type converter
it is built with `ConversionPattern(*typeConverter, opName, benefit, ctx)`. MLIR has already set `currentTypeConverter` and
converted the operands, as for any native pattern, when its `matchAndRewrite(op, operands, rewriter)` calls the Scheme procedure
with four things: `op`, the converted operands, a handle of the rewriter, and a handle of the type converter. Without a converter
(`:no-type-converter`) the second constructor is used, and the handle of the converter is `0`.

CREST uses no private MLIR API, and no change to MLIR was needed. The price is that it depends on the shape of the public
`ConversionPattern`: the binding overrides the `ArrayRef<Value>` form, and MLIR also has a 1:N form, `ArrayRef<ValueRange>`.

## 4. What a pattern can say

Each code block has a label above it. **PDL** is PDLL, the PDL IR that `mlir-pdll` writes from it, or MLIR's own PDL code.
**CREST** is the Scheme DSL. **MLIR** is MLIR's textual generic form, shown as the reference. A CREST snippet whose lines look
like `%c = arith.constant ...` is the body of a `begin-mlir-code` form, shown without the wrapper. Those lines are op-forms of the
DSL, not Scheme expressions by themselves.

Every PDL snippet was compiled with `mlir-pdll`. The CREST snippets are from `docs/manual.md` and the samples, or were run.

### 4.1 Can a rewrite be used outside a pattern?

PDL: no. A rewrite exists only inside a pattern.

**PDL: the definition in MLIR's `PDLOps.td`**
```tablegen
def PDL_RewriteOp : PDL_Op<"rewrite", [
     Terminator, HasParent<"pdl::PatternOp">, NoTerminator, NoRegionArguments,
     SingleBlock, AttrSizedOperandSegments, ...
```

**PDL: PDLL**
```pdll
// A named rewrite is a function, but only the rewrite section of a pattern can call it
Rewrite BuildFooOp(value: Value) -> Op {
  return op<my_dialect.foo>(value);
}
Pattern {
  replace op<my_dialect.old_op>(input: Value) with BuildFooOp(input);
}
```

The PDLL manual says: "All PDLL rewrites must be defined within the `rewrite` section of the pattern". The code that runs a rewrite is
in `lib/Rewrite/ByteCode.h`, which is not an installed header.

CREST: yes. `begin-mlir-code` works wherever a builder is installed. This is the Toy front end, with no pattern anywhere:

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

And this is a dialect hook that MLIR calls when a fold returns an attribute (the struct case of Ch7 is left out):

**CREST: a dialect hook**
```scheme
(:materialize-constant (builder value type loc)
  (with-current-OpBuilder builder
    (mlir::Value::getDefiningOp
     (begin-mlir-code
         r = toy.constant () (value : value) :loc loc -> type))))
```

Outside a pattern you install the builder yourself with `(with-current-OpBuilder b ...)`, or you make one with
`(with-OpBuilder b (mlir::OpBuilder::atBlockEnd block) ...)`. With no builder, `begin-mlir-code` raises `no active builder` at its
first op.

### 4.2 How is an op written?

The same op in MLIR's generic form, in PDLL (and the PDL IR that `mlir-pdll` makes from it), and in CREST.

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
`(define idx (mlir::IndexType::get))`. So any type can be written there: a type made by a call, the type of an existing value, a
tensor type, a computed type (the manual, "Result types"). The `%` in a variable is part of its name: `c` and `%c` are two different
variables. The Toy samples write result variables without it.

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
// no spelling: PDLL has no syntax for a region (4.3)
```

**CREST: the Ch6 lowering of `toy.print`**
```scheme
;; Scheme code runs inside the body
scf.for (lb ub st)
{ ^body ((iv : idx))
  (nest (cdr dims) (cons iv ivs))
  (when (pair? (cdr dims))
    (%%call-printf! loc ctx printf-ref (list nl)))
  scf.yield () :loc loc }
:loc loc
```

#### Summary

| | generic form | PDLL | CREST |
|---|---|---|---|
| operands | `(%a, %b)` | `(a, b)` | `(%a %b)` |
| attributes | `<{name = value}>` | `{name = attr<"text">}` | `(name : expr)` |
| result types | `: (operand types) -> type` | `-> (type<"i1">)`, a type written as text | `-> ty`, `ty` a Scheme variable holding any `mlir::Type` |
| regions | `({ ^bb0(%iv: index): ... })` | none | `{ ^body ((iv : idx)) ... }` |
| the result | `%r =` | a `let` variable | `%r =` |
| in a match | not applicable | the same expression | the same spelling, in `:if-match` |

PDLL is in the same family as the generic form: operands in parentheses, attributes in braces, result types after an arrow. It wraps
the pieces (`op<...>`, `attr<"...">`, `type<"...">`), a result is the value of a `let` and is not named in the op, and a region cannot
be written. CREST keeps the order of the generic form and the braces of a region, and an attribute, a type or an operand is a
Scheme expression, not text.

### 4.3 Regions in a created op

PDL cannot add a region. `pdl.operation`, the op that creates an op, has these fields, and no region:

**PDL: the definition in MLIR's `PDLOps.td`**
```tablegen
let arguments = (ins OptionalAttr<StrAttr>:$opName,
                     Variadic<PDL_InstOrRangeOf<PDL_Value>>:$operandValues,
                     Variadic<PDL_Attribute>:$attributeValues,
                     StrArrayAttr:$attributeValueNames,
                     Variadic<PDL_InstOrRangeOf<PDL_Type>>:$typeValues);
```

No other op of the `pdl` dialect makes or moves a region (`pattern`, `operand`, `operands`, `attribute`, `type`, `types`,
`result`, `results`, `range`, `replace`, `erase`, `rewrite`, `apply_native_constraint`, `apply_native_rewrite`).

The pattern below does not add a region. It shows what happens when an op whose ODS has a region is created: PDLL accepts it, and
the new op has no body.

**PDL: PDLL**
```pdll
// my.loop has `region SizedRegion<1>:$body` in ODS. The new my.loop gets no body:
Pattern => replace op<my.loop>(x: Value) with op<my.loop>(x);
```

**PDL: the PDL IR that `mlir-pdll` writes from the PDLL above**
```mlir
%3 = operation "my.loop"(%0 : !pdl.value)      // no region: the bytecode builds an OperationState without one
```

Run in the Toy Ch5 build, with an `affine.for` that has all its attributes and no region, the verifier rejects it:

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

The way to get an op with a region in PDL is C++. A native rewrite creates the op and its body, and the pattern only calls it:

**PDL: PDLL**
```pdll
Rewrite BuildLoop(x: Value) -> Op;      // written in C++ and registered by name: it creates my.loop and fills in its body
Pattern => replace op<my.loop>(x: Value) with BuildLoop(x);
```

**PDL: the PDL IR that `mlir-pdll` writes from the PDLL above**
```mlir
%3 = apply_native_rewrite "BuildLoop"(%0 : !pdl.value) : !pdl.operation
```

CREST writes one brace for each region, `^label` for a block, block arguments (written, or a computed list), and `:move-region` to
keep an existing body:

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

Limit: CREST has no syntax yet to branch from one block to another (`cf.br () ^exit`).

### 4.4 Attributes in a created op

In PDL there are three sources of an attribute:

**PDL: PDLL**
```pdll
// 1. a constant, written as text
Pattern => replace op<foo.a> with op<foo.b> {value = attr<"42 : index">};

// 2. taken from the matched op: any attribute, with no text
Pattern => replace op<foo.a> {value = v: Attr} with op<foo.b> {value = v};

// 3. computed: a native rewrite, written in C++ and registered by name (registerRewriteFunction)
Rewrite ScaleAttr(a: Attr) -> Attr;
Pattern => replace op<foo.a> {value = v: Attr} with op<foo.b> {value = ScaleAttr(v)};
```

So PDL can use any attribute (a `pdl.attribute` holds an `mlir::Attribute`), but only sources 2 and 3 are free of text. A constant
(source 1) has two limits. It is text in the MLIR syntax, which is a second language inside a string. And `mlir-pdll` parses it when it
compiles the file, so it knows only the dialects that tool loads:

**PDL: PDLL**
```pdll
op<foo.b> {value = attr<"dense<[1.0, 2.0]> : tensor<2xf64>">}        // accepted
op<foo.b> {map   = attr<"affine_map<(d0) -> (d0)>">}                 // accepted
op<foo.b> {linkage = attr<"#llvm.linkage<external>">}                // refused by the stock mlir-pdll
```

`mlir-pdll` parses the string as a separate source, so a mistake is reported at a place inside the string (the string is the file
name), not in the `.pdll` file:

**PDL: the errors of `mlir-pdll`**
```
attr<"42 :: index">                 loc("42 :: index":1:5): error: expected non-function type
attr<"#llvm.linkage<external>">     loc("#llvm.linkage<external>":1:7): error: #"llvm"<"linkage<external>"> : 'none' attribute created with unregistered dialect. If this is intended, ...
type<"indx">                        loc("indx":1:1): error: expected non-function type
```

After `mlir-pdll` the string is gone: the PDL IR has a real attribute (`%4 = attribute = 2 : i64`, in 4.2).

In CREST an attribute is a Scheme expression that returns an `mlir::Attribute`, or a shorthand such as `(value : 42 :index)`. CREST can
write the same text, with `mlir::parseAttribute`, for an attribute that has no shorthand. This is the Ch6 lowering:

**CREST: the Ch6 lowering**
```scheme
llvm.func ()
  (sym_name : "printf" :string)
  (function_type : (mlir::TypeAttr::get fnty))
  (linkage : (mlir::parseAttribute "#llvm.linkage<external>"))
  (CConv : (mlir::parseAttribute "#llvm.cconv<ccc>"))
  { }
```

### 4.5 Optional and variadic operands in a match

The op in ODS has a required, an optional and a variadic operand (the shape of `hip.dequantize_linear`):

**Both: the ODS definition of the op**
```tablegen
def DQOp : My_Op<"dq", [AttrSizedOperandSegments]> {
  let arguments = (ins AnyType:$x, Optional<AnyType>:$zp, Variadic<AnyType>:$rest);
  let results = (outs AnyType:$out);
}
```

In PDL the groups come from the ODS definition, so `mlir-pdll` must know the op:

**PDL: PDLL**
```pdll
op<my.dq>(x: Value, zp: ValueRange, rest: ValueRange)    // compiles: zp is a range of 0 or 1
op<my.dq>(x: Value, zp: Value,      rest: ValueRange)    // compiles: zp must have exactly one value
op<my.dq>(x: Value, rest: ValueRange)                    // error: invalid number of operand groups for `my.dq`; expected 3, but got 2
```

At run time the bytecode finds a group in `operandSegmentSizes` when the op has the trait `AttrSizedOperandSegments`, which only a
registered op has. Otherwise it takes the last group as the range. A group written as one `Value` must have exactly one value, or the
bytecode returns a null pointer (`executeGetOperandsResults` in `ByteCode.cpp`). `SameVariadicOperandSize` is not supported (a
`FIXME` in the same function).

In CREST `(:optional ...)` and `(:variadic ...)` go in the operand list. The op needs an `operandSegmentSizes` attribute, but it does
not need to be registered (the hip-fusion tests run with `-allow-unregistered-dialect`).

**CREST**
```scheme
%dq = hip.dequantize_linear (%ctx %x %scale (:optional %zp) %init)
:then-let ([zp (if (unbound-value? %zp) 0 (extract-zp %zp))])      ; absent: %zp is the absent value

%op = my.op (%x (:optional %y) (:variadic %z))                     ; required, optional, variadic; %z is a Scheme list
%op = my.op (%x (:optional %a %b) %y)                              ; two optional slots
```

### 4.6 Which mistakes are caught, and when

`!pdl.value` and `!pdl.type` (`Value` and `Type` in PDLL) say what kind of thing a name is: a value, a type, an attribute, an
operation, or a range of them. They do not say which MLIR type it has: every operand of every `pdl.operation` prints as
`!pdl.value`, so, unlike the generic form (`: (i32, i32) -> i1`), the PDL IR says nothing about MLIR types.

So PDL catches a wrong kind when `mlir-pdll` compiles the file, and a wrong MLIR type only when the op is built and verified.
CREST catches a wrong kind when the op is built, and a wrong MLIR type in the same way as PDL.

**A wrong kind: PDL**
```pdll
op<arith.cmpi>(a, type<"i32">) {predicate = attr<"2 : i64">} -> (type<"i1">)
// mlir-pdll: error: unable to convert expression of type `Type` to the expected type of `ValueRange`
```

**A wrong kind: CREST**
```scheme
%c = arith.constant () (value : 42 :index) -> "not a type"
;; Scheme error: invalid foreign-procedure argument ("not a type")
```

**Three wrong MLIR types: PDL (a PDLL pattern that replaces the `toy.print` of `print.toy`)**
```pdll
op<arith.cmpi>(a, a) {predicate = attr<"2 : i64">} -> (type<"f32">)     // a is an i32 constant: the result must be i1
op<arith.cmpi>(a, b) {predicate = attr<"2 : i64">} -> (type<"i1">)      // a is an i32 constant, b an i64 one
op<arith.cmpi>(a, a) {predicate = attr<"2 : i64">} -> (type<"i1">)      // a is an f32 constant
```

**Three wrong MLIR types: CREST (then `(mlir::Operation::verify? module)`)**
```scheme
%r = arith.cmpi (%a %a) (predicate : 2 :i64) -> f32            ; a is an i32 constant
%r = arith.cmpi (%a %b) (predicate : 2 :i64) -> i1             ; a is an i32 constant, b an i64 one
%r = arith.cmpi (%a %a) (predicate : 2 :i64) -> i1             ; a is an f32 constant
```

Both compile or build. The verifier of MLIR then rejects each one, with the same three messages (here as `toyc-ch5` prints them,
exit status 4; `scheme-mlir` prints the same text and `verify?` returns `#f`):

```
error: 'arith.cmpi' op result #0 must be bool-like, but got 'f32'
error: 'arith.cmpi' op requires all operands to have the same type
error: 'arith.cmpi' op operand #0 must be signless-non-zero-bitwidth-integer-like, but got 'f32'
```

The location differs. The PDL error is at the Toy op that was replaced (`print.toy:3:3`). The CREST error is, by default, at the
line of the op-form in the `.sls` file (`loc("c1.sls":29:26)`); `:loc` overrides it.

## 5. What the PDL path costs

- **PDL code inside MLIR.** The pattern set, `PatternApplicator`, `FrozenRewritePatternSet` and the dialect conversion each have PDL
  code (`PatternMatch.h` holds a PDL member, a constructor, and `add` and `insert` overloads for it). It all sits behind
  `MLIR_ENABLE_PDL_IN_PATTERNMATCH`; with the option off the header has stub classes.
- **A long tool chain.** `mlir-pdll -x=cpp` writes `ToyLowering.h.inc`, with the pattern as PDL IR text in a C++ string. At run time
  the generated constructor parses that text (`parseSourceString`). Then `FrozenRewritePatternSet` converts the module to PDL
  interpreter IR (`convertPDLToPDLInterp`) and builds the bytecode (`PDLByteCode`). The `pdl` and `pdl_interp` dialects must be
  loaded for this.
- **Names that must match.** The `.pdll` declares `convertValue`, and C++ registers `"convertValue"`. Nothing checks that the two
  agree before the pattern runs. A missing registration was tried (a crash); a misspelled name was not.
- **More helpers.** A condition that PDLL cannot say, and a rewrite that is not "replace with an op", is a native C++ function
  registered in the same way. In the Ch5 experiment only two of the seven patterns (`toy.print` and `toy.return`) could be PDLL
  alone. The other five build loop nests or move a region.

## 6. What CREST gives up

- A mistake in a CREST pattern is found at the first import, not at build time (README, "What you give up").
- Edit and run needs development mode. In boot mode the `.sls` files are inside the binary, and a change needs a rebuild.
