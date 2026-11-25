# Toy Ch3 — Canonicalization Patterns

Ch3 adds four canonicalization rewrite patterns, which the ops bring themselves
(`:get-canonicalization-patterns` in `toy.sls`, `hasCanonicalizer` in C++) so MLIR's
canonicalizer pass finds them, and adds support for reading `.mlir` files directly as input.

## What's new over Ch2

| Feature | Ch2 | Ch3 |
|---|---|---|
| Actions | `ast`, `mlir` | `ast`, `mlir` |
| Optimization flag | — | `--opt` |
| Input formats | `.toy` only | `.toy` or `.mlir` |
| Canonicalization passes | — | 4 patterns (see below) |

### Canonicalization patterns (`combine.sls`)

These mirror `mlir/examples/toy/Ch3/mlir/ToyCombine.cpp` and `ToyCombine.td`:

| Pattern | Rule |
|---|---|
| `SimplifyRedundantTranspose` | `transpose(transpose(x))` → `x` |
| `ReshapeReshapeOpt` | `reshape(reshape(x))` → `reshape(x)` |
| `RedundantReshape` | `reshape(x)` → `x` when input and output types are identical |
| `FoldConstantReshape` | `reshape(constant(x))` → `constant(x')` (folds into new constant) |

## Commands

`./toyc` runs `$CREST_BUILD_DIR/tools/scheme-mlir/scheme-mlir` when `CREST_BUILD_DIR` is set,
and the `scheme-mlir` on `PATH` otherwise.

```sh
# Dump the AST
./toyc example.toy --emit=ast

# Dump raw MLIR (no optimization)
./toyc example.toy --emit=mlir

# Dump MLIR after canonicalization passes
./toyc example.toy --emit=mlir --opt

# Parse a .mlir file directly
./toyc some.mlir --emit=mlir

# Parse a .mlir file and apply canonicalization passes
./toyc some.mlir --emit=mlir --opt
```

## Examples of the rules

`example.toy` only shows `FoldConstantReshape`. The first two programs below are the ones of the C++ tutorial
(`mlir/test/Examples/Toy/Ch3/`); `reshape_reshape.toy` is new. Each program has a copy in `test/toy/ch3/`, and
three tests: `action-ast-<name>.mlir`, `action-mlir-<name>.mlir` and
`action-mlir-opt-<name>.mlir` (`<name>` is the file name with `-` for `_`, and `example` for `example.toy`). They check the whole output line by line.

To see what `--opt` does, diff the output without it and with it. The lines with `-` are removed and the lines with
`+` are new. A value that comes after a removed op gets a lower number, so some lines differ only in their `%` numbers.

```sh
opt-diff() { diff -u --label 'without --opt' --label 'with --opt' \
                   <(./toyc "$1" --emit=mlir) <(./toyc "$1" --emit=mlir --opt); }
```

### `transpose_transpose.toy`

```sh
opt-diff transpose_transpose.toy
```

```diff
--- without --opt
+++ with --opt
@@ -1,14 +1,11 @@
 module {
   toy.func @transpose_transpose(%arg0: tensor<*xf64>) -> tensor<*xf64> {
-    %0 = toy.transpose(%arg0 : tensor<*xf64>) to tensor<*xf64>
-    %1 = toy.transpose(%0 : tensor<*xf64>) to tensor<*xf64>
-    toy.return %1 : tensor<*xf64>
+    toy.return %arg0 : tensor<*xf64>
   }
   toy.func @main() {
     %0 = toy.constant dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>
-    %1 = toy.reshape(%0 : tensor<2x3xf64>) to tensor<2x3xf64>
-    %2 = toy.generic_call @transpose_transpose(%1) : (tensor<2x3xf64>) -> tensor<*xf64>
-    toy.print %2 : tensor<*xf64>
+    %1 = toy.generic_call @transpose_transpose(%0) : (tensor<2x3xf64>) -> tensor<*xf64>
+    toy.print %1 : tensor<*xf64>
     toy.return
   }
 }
```

`SimplifyRedundantTranspose` removes the two `toy.transpose` ops, so the function returns its argument. In `main`, the
`toy.reshape` of the constant to its own type, which `var a<2, 3>` makes, is removed too.

### `trivial_reshape.toy`

```sh
opt-diff trivial_reshape.toy
```

```diff
--- without --opt
+++ with --opt
@@ -1,10 +1,7 @@
 module {
   toy.func @main() {
-    %0 = toy.constant dense<[1.000000e+00, 2.000000e+00]> : tensor<2xf64>
-    %1 = toy.reshape(%0 : tensor<2xf64>) to tensor<2x1xf64>
-    %2 = toy.reshape(%1 : tensor<2x1xf64>) to tensor<2x1xf64>
-    %3 = toy.reshape(%2 : tensor<2x1xf64>) to tensor<2x1xf64>
-    toy.print %3 : tensor<2x1xf64>
+    %0 = toy.constant dense<[[1.000000e+00], [2.000000e+00]]> : tensor<2x1xf64>
+    toy.print %0 : tensor<2x1xf64>
     toy.return
   }
 }
```

The flat `tensor<2xf64>` constant and the three `toy.reshape` ops, one for each `var`, become one constant of type
`tensor<2x1xf64>`.

### `reshape_reshape.toy`

```sh
opt-diff reshape_reshape.toy
```

```diff
--- without --opt
+++ with --opt
@@ -1,14 +1,12 @@
 module {
   toy.func @reshape_reshape(%arg0: tensor<*xf64>) -> tensor<*xf64> {
-    %0 = toy.reshape(%arg0 : tensor<*xf64>) to tensor<2x3xf64>
-    %1 = toy.reshape(%0 : tensor<2x3xf64>) to tensor<3x2xf64>
-    toy.return %1 : tensor<3x2xf64>
+    %0 = toy.reshape(%arg0 : tensor<*xf64>) to tensor<3x2xf64>
+    toy.return %0 : tensor<3x2xf64>
   }
   toy.func @main() {
     %0 = toy.constant dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>
-    %1 = toy.reshape(%0 : tensor<2x3xf64>) to tensor<2x3xf64>
-    %2 = toy.generic_call @reshape_reshape(%1) : (tensor<2x3xf64>) -> tensor<*xf64>
-    toy.print %2 : tensor<*xf64>
+    %1 = toy.generic_call @reshape_reshape(%0) : (tensor<2x3xf64>) -> tensor<*xf64>
+    toy.print %1 : tensor<*xf64>
     toy.return
   }
 }
```

`ReshapeReshapeOpt` replaces the two reshapes of the argument, `tensor<*xf64>` to `2x3` to `3x2`, by one reshape to
`3x2`. The input is an argument and the shapes differ, so no other rule can do this. In `main` the reshape of the
constant to its own type is removed, as above.

### Each rule on its own

| Rule | Program | Test |
|---|---|---|
| `SimplifyRedundantTranspose` | `transpose_transpose.toy` | `action-mlir-opt-transpose-transpose.mlir` |
| `ReshapeReshapeOpt` | `reshape_reshape.toy` | `action-mlir-opt-reshape-reshape.mlir` |
| `RedundantReshape` | none, MLIR text only | `redundant-reshape.mlir` |
| `FoldConstantReshape` | `trivial_reshape.toy`, `example.toy` | `action-mlir-opt-trivial-reshape.mlir`, `action-mlir-opt-example.mlir` |

Taking one pattern out of `combine.sls` makes the tests of its row fail and no other.

`RedundantReshape` has no Toy program. In Toy a value with a known shape is a constant (`FoldConstantReshape` removes
a reshape of it) or the result of a reshape (`ReshapeReshapeOpt` removes it), so another rule always does the work.
`redundant-reshape.mlir` is MLIR text, where the input of the reshape is an argument with the same type.

> **Note:** Ch3 does not inline function calls — `main` emits `toy.generic_call`
> ops and `multiply_transpose` remains a separate function. Inlining is added in
> a later chapter. With `--opt`, `FoldConstantReshape` does fire on
> `var b<2, 3> = [1, 2, 3, 4, 5, 6]` in `example.toy`: MLIRGen emits a flat
> `tensor<6xf64>` constant plus a reshape, and the pattern folds them into a
> single `tensor<2x3xf64>` constant. `SimplifyRedundantTranspose` does not fire
> because the transpositions inside `multiply_transpose` are not nested.

## The expansion of the dialect

`define-dialect` expands as [Ch2](../ch2/README.md#inspecting-macro-expansions) shows. What Ch3 adds to it is the
`:get-canonicalization-patterns` clause of `toy.transpose` and `toy.reshape` in `toy.sls`: in the expansion it is a
function of `patterns` in the callbacks of the op, which calls `toy:add-transpose-canonicalization-patterns!` or
`toy:add-reshape-canonicalization-patterns!` of `combine.sls`.

```sh
tools/debug-define-dialect samples/toy/ch3/toy.sls | grep -n canonicalization
```

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect, with its text form | `define-dialect`, `:assembly-format` | as in Ch2 |
| Every op `mlir-gen.sls` creates | `begin-mlir-code` | as in Ch2 |
| The four canonicalization patterns | `define-rewrite-pattern` | each one is a match and a rewrite; see [Why the patterns are written in the DSL](#why-the-patterns-are-written-in-the-dsl) |
| Registering the patterns | `define-pattern-set` (`combine.sls`), `:get-canonicalization-patterns` (`toy.sls`) | a table of (op, pattern, benefit) per op, registered by the op as C++ `getCanonicalizationPatterns` does |
| Applying them | `PassManager` nested on `toy.func` with `createCanonicalizerPass` (`toyc.sls`) | the canonicalizer also folds and erases dead `pure` ops, as in the C++ `toyc` |

## Why the patterns are written in the DSL

The C++ Toy writes its four patterns in two languages: `ToyCombine.td` has three of them as DRR (TableGen's
declarative rewrite rules), and `ToyCombine.cpp` has `SimplifyRedundantTranspose` as a hand-written class. The two
styles do not mix: a pattern that needs both a structure to match and some logic has to choose one, or put C++ in
strings inside DRR. `combine.sls` writes all four in one way, as a declaration with Scheme where it needs logic.
Here they are, pattern to pattern.

### `SimplifyRedundantTranspose`

<table>
<tr><th>C++ (<code>ToyCombine.cpp</code>, comments left out)</th><th>CREST DSL (<code>combine.sls</code>)</th></tr>
<tr><td>

```cpp
struct SimplifyRedundantTranspose : public mlir::OpRewritePattern<TransposeOp> {
  SimplifyRedundantTranspose(mlir::MLIRContext *context)
      : OpRewritePattern<TransposeOp>(context, /*benefit=*/1) {}

  llvm::LogicalResult
  matchAndRewrite(TransposeOp op,
                  mlir::PatternRewriter &rewriter) const override {
    mlir::Value transposeInput = op.getOperand();
    TransposeOp transposeInputOp = transposeInput.getDefiningOp<TransposeOp>();
    if (!transposeInputOp)
      return failure();
    rewriter.replaceOp(op, {transposeInputOp.getOperand()});
    return success();
  }
};
```

</td><td>

```scheme
(define-rewrite-pattern (%%simplify-redundant-transpose op rewriter)
  :if-match
    %inner = toy.transpose (%in)
    %out   = toy.transpose (%inner)
  :rewrite %out :with
    %in)
```

</td></tr>
</table>

The C++ class finds the match by walking: take the operand, ask for its defining op as a `TransposeOp`, give up when
there is none, and say `success()` or `failure()`. The DSL says what is matched, a transpose of a transpose, and what
replaces it. A match that does not hold is simply no match.

### `ReshapeReshapeOpt`

<table>
<tr><th>DRR (<code>ToyCombine.td</code>)</th><th>CREST DSL (<code>combine.sls</code>)</th></tr>
<tr><td>

```tablegen
def ReshapeReshapeOptPattern : Pat<(ReshapeOp(ReshapeOp $arg)),
                                   (ReshapeOp $arg)>;
```

</td><td>

```scheme
(define-rewrite-pattern (%%reshape-reshape op rewriter)
  :if-match
    %inner = toy.reshape (%in)
    %out   = toy.reshape (%inner)
  :then-let
    ([!out-type (mlir::Value::getType %out)])
  :rewrite %out :with
    result = toy.reshape (%in) -> !out-type)
```

</td></tr>
</table>

The two have the same shape. The DSL also writes the type of the new reshape (`!out-type`, the type of the reshape it
replaces), which the DRR pattern does not write.

### `RedundantReshape`

<table>
<tr><th>DRR (<code>ToyCombine.td</code>)</th><th>CREST DSL (<code>combine.sls</code>)</th></tr>
<tr><td>

```tablegen
def TypesAreIdentical : Constraint<CPred<"$0.getType() == $1.getType()">>;
def RedundantReshapeOptPattern : Pat<
  (ReshapeOp:$res $arg), (replaceWithValue $arg),
  [(TypesAreIdentical $res, $arg)]>;
```

</td><td>

```scheme
(define-rewrite-pattern (%%redundant-reshape op rewriter)
  :if-match
    %out = toy.reshape (%in)
      :where
    (equal? (mlir::Value::getType %out) (mlir::Value::getType %in))
  :rewrite %out :with
    %in)
```

</td></tr>
</table>

The condition is the difference. In DRR it is a `Constraint` with a `CPred` string, and `$0` and `$1` are the places of
the arguments where the constraint is used, `(TypesAreIdentical $res, $arg)`; nothing in the string names them, and
only the C++ compiler reads it, in the generated `ToyCombine.inc`. In the DSL the condition is a Scheme expression under
the value it is about, and it uses the names of the match, `%out` and `%in`.

### `FoldConstantReshape`

<table>
<tr><th>DRR (<code>ToyCombine.td</code>)</th><th>CREST DSL (<code>combine.sls</code>)</th></tr>
<tr><td>

```tablegen
def ReshapeConstant :
  NativeCodeCall<"$0.reshape(::llvm::cast<ShapedType>($1.getType()))">;
def FoldConstantReshapeOptPattern : Pat<
  (ReshapeOp:$res (ConstantOp $arg)),
  (ConstantOp (ReshapeConstant $arg, $res))>;
```

</td><td>

```scheme
(define-rewrite-pattern (%%fold-constant-reshape op rewriter)
  :if-match
    %const = toy.constant ()
    %out   = toy.reshape (%const)
  :then-let
    ([!out-type (mlir::Value::getType %out)]
     [old-attr  (mlir::Operation::getAttr (mlir::Value::getDefiningOp %const) "value")]
     [new-attr  (mlir::DenseElementsAttr::reshape old-attr !out-type)])
  :rewrite %out :with
    result = toy.constant ()
    (value : new-attr)
    -> !out-type)
```

</td></tr>
</table>

DRR cannot compute the new constant, so it calls out to C++ in a string (`NativeCodeCall`), with its own `$0` and
`$1`. The DSL computes it in `:then-let` with ordinary Scheme: `old-attr` and `new-attr` are names for values, and
`mlir::DenseElementsAttr::reshape` is called as any other binding is.

### Registering the patterns

<table>
<tr><th>C++ (<code>ToyCombine.cpp</code>)</th><th>CREST DSL (<code>combine.sls</code>)</th></tr>
<tr><td>

```cpp
void TransposeOp::getCanonicalizationPatterns(RewritePatternSet &results,
                                              MLIRContext *context) {
  results.add<SimplifyRedundantTranspose>(context);
}

void ReshapeOp::getCanonicalizationPatterns(RewritePatternSet &results,
                                            MLIRContext *context) {
  results.add<ReshapeReshapeOptPattern, RedundantReshapeOptPattern,
              FoldConstantReshapeOptPattern>(context);
}
```

</td><td>

```scheme
(define-pattern-set toy:add-transpose-canonicalization-patterns!
  ("toy.transpose" %%simplify-redundant-transpose 1))

(define-pattern-set toy:add-reshape-canonicalization-patterns!
  ("toy.reshape" %%reshape-reshape 1)
  ("toy.reshape" %%redundant-reshape 1)
  ("toy.reshape" %%fold-constant-reshape 1))
```

</td></tr>
</table>

Each op brings its patterns, as `getCanonicalizationPatterns` does in C++. The benefit (`1`) is a column of the table.

### What this adds up to

- **The match looks like the IR.** `%out = toy.reshape (%in)` is the op as MLIR prints it, and a name that is used
  twice is the same value. DRR writes a prefix tree with `$` names, which is neither MLIR nor C++.
- **The host language is there.** The conditions and the computations are plain Scheme, and the names of the match
  are Scheme variables. A condition can be any function, defined in another library and used by many patterns.
- **A mistake is reported where it is written.** A misspelled name in a condition (`%inn` for `%in`) stops the
  library when it loads, with the line and the column of the typo.
- **It scales.** A larger pattern is more blocks of the same form, each with its conditions under it, and not a deeper
  tree or more nesting. Real ones are in `samples/passes/hip-fusion`: `qlpnorm.sls` matches a chain of three ops with
  conditions on each op, and `qgemm.sls` has four patterns that share their conditions. The four patterns of Toy are
  small, so this chapter shows the difference least; those files show it best.
- **No rebuild.** In development mode a change to a pattern takes effect when the program runs again.

What it does not give: the checks happen when the library loads, and not when C++ is compiled.

See also "Why not PDL / DRR / C++?" in the [main README](../../../README.md#why-not-pdl--drr--c).
