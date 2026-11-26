# Toy Ch4 — Inlining

Ch4 inlines `toy.generic_call` and adds `toy.cast` to handle ranked/unranked
tensor mismatches that appear at call boundaries after inlining.

The inlining is done by MLIR's inliner pass, as in the C++ tutorial. The pass needs four things from the dialect.
Two are new in Ch4: `toy.generic_call` implements `CallOpInterface` (its `:interfaces` give the callee, the argument
operands and `(getArgOperandsMutable :all-operands)`, as the C++ op does with `getCallableForCallee` and
`getArgOperands`), and the dialect has a `DialectInlinerInterface`, which says that inlining is legal and how to convert
a call operand to the type of the parameter of the callee. The other two are there since Ch2: `toy.func` is callable
(`CallableOpInterface`) and `toy.return` is a terminator (`:traits (terminator)`). Like Ch2 and Ch3, Ch4 needs LLVM 23.

## Try it

`example.toy` has `multiply_transpose`, which multiplies the transposes of its two arguments whatever their shapes
are, and `main`, which builds two `2x3` tensors, calls the function four times and prints `e`:

```text
def multiply_transpose(a, b) {
  return transpose(a) * transpose(b);
}

def main() {
  var a = [[1, 2, 3], [4, 5, 6]];
  var b<2, 3> = [1, 2, 3, 4, 5, 6];
  var c = multiply_transpose(a, b);
  var d = multiply_transpose(b, a);
  var e = multiply_transpose(c, d);
  var f = multiply_transpose(a, c);
  print(e);
}
```

Run the commands in this directory. `./toyc` finds `scheme-mlir` through `CREST_BUILD_DIR` or `PATH`, see the commands of
the [Ch3 README](../ch3/README.md#commands).

`--emit=ast` prints the AST as in [Ch1](../ch1/README.md#try-it), and `--opt` changes nothing there.

### `--emit=mlir`

```sh
./toyc example.toy --emit=mlir
```

```mlir
module {
  toy.func private @multiply_transpose(%arg0: tensor<*xf64>, %arg1: tensor<*xf64>) -> tensor<*xf64> {
    %0 = toy.transpose(%arg1 : tensor<*xf64>) to tensor<*xf64>
    %1 = toy.transpose(%arg0 : tensor<*xf64>) to tensor<*xf64>
    %2 = toy.mul %1, %0 : tensor<*xf64>
    toy.return %2 : tensor<*xf64>
  }
  toy.func @main() {
    %0 = toy.constant dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>
    %1 = toy.constant dense<[1.000000e+00, 2.000000e+00, 3.000000e+00, 4.000000e+00, 5.000000e+00, 6.000000e+00]> : tensor<6xf64>
    %2 = toy.reshape(%1 : tensor<6xf64>) to tensor<2x3xf64>
    %3 = toy.generic_call @multiply_transpose(%0, %2) : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
    %4 = toy.generic_call @multiply_transpose(%2, %0) : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
    %5 = toy.generic_call @multiply_transpose(%3, %4) : (tensor<*xf64>, tensor<*xf64>) -> tensor<*xf64>
    %6 = toy.generic_call @multiply_transpose(%0, %3) : (tensor<2x3xf64>, tensor<*xf64>) -> tensor<*xf64>
    toy.print %5 : tensor<*xf64>
    toy.return
  }
}
```

Each Toy function is a `toy.func`. `multiply_transpose` is `private`, and its types are `tensor<*xf64>`, unranked,
because its arguments can have any shape. In `main`, `a` is a constant, and `var b<2, 3> = [1, 2, 3, 4, 5, 6]` is a flat
`tensor<6xf64>` constant and a `toy.reshape` to `2x3`. Each of the four calls is a `toy.generic_call` whose result is
unranked, so the third call passes `(tensor<*xf64>, tensor<*xf64>)` where the first two pass ranked tensors.

### `--emit=mlir --opt`

```sh
./toyc example.toy --emit=mlir --opt
```

```mlir
module {
  toy.func @main() {
    %0 = toy.constant dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>
    %1 = toy.transpose(%0 : tensor<2x3xf64>) to tensor<3x2xf64>
    %2 = toy.mul %1, %1 : tensor<3x2xf64>
    %3 = toy.transpose(%2 : tensor<3x2xf64>) to tensor<2x3xf64>
    %4 = toy.mul %3, %3 : tensor<2x3xf64>
    toy.print %4 : tensor<2x3xf64>
    toy.return
  }
}
```

The pipeline of this chapter ran: inline, shape inference, canonicalize and CSE (see [`--opt` pipeline](#--opt-pipeline-toycsls)).
All four calls are inlined, `multiply_transpose` is gone, and every type is ranked. `f` is not used, so its code is
gone. `a` and `b` became the same constant, so the first `toy.mul` multiplies a value with itself.

A `.mlir` file is an input too, as in Ch3: `./toyc some.mlir --emit=mlir --opt` runs the same pipeline on it. Here
`some.mlir` is the output of `--emit=mlir` above, and the result is the output of `--emit=mlir --opt` above.

### What `--opt` changed

Diff the output without `--opt` and with it. The lines with `-` are removed and the lines with `+` are new.

```sh
opt-diff() { diff -u --label 'without --opt' --label 'with --opt' \
                   <(./toyc "$1" --emit=mlir) <(./toyc "$1" --emit=mlir --opt); }
opt-diff example.toy
```

```diff
--- without --opt
+++ with --opt
@@ -1,19 +1,11 @@
 module {
-  toy.func private @multiply_transpose(%arg0: tensor<*xf64>, %arg1: tensor<*xf64>) -> tensor<*xf64> {
-    %0 = toy.transpose(%arg1 : tensor<*xf64>) to tensor<*xf64>
-    %1 = toy.transpose(%arg0 : tensor<*xf64>) to tensor<*xf64>
-    %2 = toy.mul %1, %0 : tensor<*xf64>
-    toy.return %2 : tensor<*xf64>
-  }
   toy.func @main() {
     %0 = toy.constant dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>
-    %1 = toy.constant dense<[1.000000e+00, 2.000000e+00, 3.000000e+00, 4.000000e+00, 5.000000e+00, 6.000000e+00]> : tensor<6xf64>
-    %2 = toy.reshape(%1 : tensor<6xf64>) to tensor<2x3xf64>
-    %3 = toy.generic_call @multiply_transpose(%0, %2) : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
-    %4 = toy.generic_call @multiply_transpose(%2, %0) : (tensor<2x3xf64>, tensor<2x3xf64>) -> tensor<*xf64>
-    %5 = toy.generic_call @multiply_transpose(%3, %4) : (tensor<*xf64>, tensor<*xf64>) -> tensor<*xf64>
-    %6 = toy.generic_call @multiply_transpose(%0, %3) : (tensor<2x3xf64>, tensor<*xf64>) -> tensor<*xf64>
-    toy.print %5 : tensor<*xf64>
+    %1 = toy.transpose(%0 : tensor<2x3xf64>) to tensor<3x2xf64>
+    %2 = toy.mul %1, %1 : tensor<3x2xf64>
+    %3 = toy.transpose(%2 : tensor<3x2xf64>) to tensor<2x3xf64>
+    %4 = toy.mul %3, %3 : tensor<2x3xf64>
+    toy.print %4 : tensor<2x3xf64>
     toy.return
   }
 }
```

- `multiply_transpose` and the four `toy.generic_call` ops are gone: the inliner found the calls through
  `CallOpInterface`, asked the dialect whether to inline, and copied the body into `main` (points 1 and 2 below).
- Every type is ranked, `tensor<3x2xf64>` or `tensor<2x3xf64>`, and none is `tensor<*xf64>`: shape inference (point 4 below).
- No `toy.cast` is left (point 3 below). The next table shows it.
- The flat constant and its reshape became a `tensor<2x3xf64>` constant equal to `a`, and CSE merged the two.

### Take one pass out

Delete one line of `%%run-opt-pipeline!` in `toyc.sls` and run `./toyc example.toy --emit=mlir --opt` again:

| Line removed | What you see |
|---|---|
| `(mlir::createInlinerPass)` | `error: Shape inference failed, 3 operations couldn't be inferred`, then `Optimization pipeline failed`: the calls and the unranked function are still there, so there is nothing to infer from (point 5 below) |
| `(toy:shape-inference-pass)` | the cast of the inliner stays, and so do the unranked types (points 3 and 4 below):<br>`%1 = toy.cast %0 : tensor<2x3xf64> to tensor<*xf64>` |
| `(mlir::createCSEPass)` | two equal `tensor<2x3xf64>` constants stay, and so do the repeated `toy.transpose` ops of them |
| `(mlir::createCanonicalizerPass)` | the same output: this program does not need it |

## What you learn about MLIR here

Ch3 showed that an op can bring its own rewrite patterns. Ch4 is the other direction: MLIR passes that know nothing
about Toy, and what the dialect has to tell them.

The links are permalinks: the Scheme files of this chapter at the commit `2505012c4bec` of this repository, and the C++ files of the LLVM Toy tutorial at the commit `392dfff97d29` of LLVM.

1. **A generic pass asks through interfaces.** The inliner works on any dialect, so it does not look at `toy.*` ops.
   An op interface says what an op is: `CallOpInterface` on `toy.generic_call` (the callee and the argument operands)
   and `CallableOpInterface` on `toy.func` (the body and the types). A dialect interface says what the dialect
   allows: `DialectInlinerInterface`. They are the `:interfaces` clauses in `toy.sls`; in C++ they are
   `DeclareOpInterfaceMethods<CallOpInterface>` in `Ops.td` and `ToyInlinerInterface` in `Dialect.cpp`.
   - Scheme: [`toy.generic_call` (`toy.sls` L302-L319)](https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/toy.sls#L302-L319), [`toy.func` interfaces (`toy.sls` L324-L341)](https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/toy.sls#L324-L341), [`DialectInlinerInterface` (`toy.sls` L195-L210)](https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/toy.sls#L195-L210)
   - C++: [`GenericCallOp` (`Ops.td` L198-L237)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/include/toy/Ops.td#L198-L237), [`ToyInlinerInterface` (`Dialect.cpp` L47-L96)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/mlir/Dialect.cpp#L47-L96)
2. **Inlining can make a type mismatch, and the dialect repairs it.** The callee takes `tensor<*xf64>` and the caller
   passes a ranked tensor. The inliner calls `materializeCallConversion`, which creates a `toy.cast`, and
   `handleTerminator`, which replaces the results of the call by the operands of the cloned `toy.return`.
   [inlining.md](inlining.md) walks through it.
   - Scheme: [`handleTerminator` (`toy.sls` L199-L203)](https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/toy.sls#L199-L203), [`materializeCallConversion` (`toy.sls` L205-L210)](https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/toy.sls#L205-L210)
   - C++: [`handleTerminator` (`Dialect.cpp` L76-L84)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/mlir/Dialect.cpp#L76-L84), [`materializeCallConversion` (`Dialect.cpp` L91-L95)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/mlir/Dialect.cpp#L91-L95)
3. **An op can exist only to bridge one step of a pipeline.** `toy.cast` has the traits `pure` and
   `same-operands-and-result-shape`. When shape inference has given the types, the cast changes nothing, and its folder
   (`:fold`) removes it.
   - Scheme: [`toy.cast` (`toy.sls` L289-L300)](https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/toy.sls#L289-L300)
   - C++: [`CastOp` (`Ops.td` L118-L137)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/include/toy/Ops.td#L118-L137)
4. **Shape inference is a rewrite to a fixed point.** Each pattern gives an op with an unranked result a precise type
   when its operands are ranked, and the greedy rewriter repeats until nothing changes (`shape-inference.sls`). The C++
   tutorial writes the same with an op interface (`ShapeInferenceOpInterface`) and a pass with a worklist.
   - Scheme: [the four patterns (`shape-inference.sls` L37-L78)](https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/shape-inference.sls#L37-L78), [the pass (`shape-inference.sls` L89-L107)](https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/shape-inference.sls#L89-L107)
   - C++: [`ShapeInferenceOpInterface` (`ShapeInferenceInterface.td` L18-L28)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/include/toy/ShapeInferenceInterface.td#L18-L28), [the pass and its worklist (`ShapeInferencePass.cpp` L55-L117)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/mlir/ShapeInferencePass.cpp#L55-L117)
5. **The order of the passes matters.** A `PassManager` runs the inliner on the module and the other passes nested on
   `toy.func`: inline, then shape inference, then canonicalize and CSE (`toyc.sls`; `toyc.cpp` in C++). Each pass needs
   what the one before made: after inlining the transpositions are in one function, so canonicalization can remove
   them. CSE merges equal ops, which is safe for ops marked `pure`.
   - Scheme: [`%%run-opt-pipeline!` (`toyc.sls` L82-L90)](https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/toyc.sls#L82-L90)
   - C++: [the pipeline (`toyc.cpp` L129-L137)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/toyc.cpp#L129-L137)

## What's new over Ch3

| Feature | Ch3 | Ch4 |
|---|---|---|
| `toy.generic_call` | stays as call op | inlined into caller |
| `toy.cast` op | — | inserted at ranked/unranked boundaries |
| `DialectInlinerInterface` | — | added to toy dialect |
| `--opt` pipeline | canonicalization only | inline → shape inference → canonicalize |

### `DialectInlinerInterface` (`toy.sls`)

Three legality predicates — all return `true` (toy permits inlining
everywhere):

| Method | Guards |
|---|---|
| `isLegalToInline/call` | whether a call may be inlined |
| `isLegalToInline/region` | whether a region may be inlined into a dest region |
| `isLegalToInline/op` | whether a single op may be inlined |

Two action callbacks:

**`handleTerminator`** — called with the cloned `toy.return` and the list of
call-site SSA results that need new definitions. Redirects each call result to
the corresponding return operand via `replaceAllUsesWith`. See
[inlining.md](inlining.md) for a step-by-step walkthrough.

**`materializeCallConversion`** — called when the return type and call-result
type differ (ranked vs. unranked tensor). Inserts a `toy.cast` op to bridge
the mismatch. Shape inference resolves the cast in the next pipeline step.

### `toy.cast` op (`toy.sls`)

Bridges a ranked/unranked tensor mismatch at a call boundary. Inserted
automatically by `materializeCallConversion`; not written by hand in Toy
source. Its text form is the C++ `assemblyFormat`, declared with `:assembly-format`
(`toy.cast %0 : tensor<2xf64> to tensor<*xf64>`).

### `--opt` pipeline (`toyc.sls`)

Three steps run in order when `--opt` is passed:

1. **Inline** — MLIR's inliner pass (`mlir::createInlinerPass`, run on a
   `PassManager` in `toyc.sls`) replaces each `toy.generic_call` with the
   callee's body, calling the dialect's `materializeCallConversion` to cast a
   ranked argument to the callee's unranked parameter type, and erases the
   private functions that are dead afterwards.
2. **Shape inference** — four rewrite patterns (`shape-inference.sls`) for
   `toy.add`, `toy.mul`, `toy.cast` and `toy.transpose`. Each fires on an op
   with an unranked result whose operands are ranked and replaces it with the
   same op with the inferred result type; the greedy rewriter applies them to
   a fixed point.
3. **Canonicalize + CSE** — nested on `toy.func`: MLIR's canonicalizer, with the patterns of
   [Ch3](../ch3/README.md) that the ops register themselves, and CSE, which is new. After inlining and shape
   inference the transpositions are in the same function, so the redundant-transpose pattern fires.

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect, `mlir-gen.sls`, the canonicalization patterns | `define-dialect`, `begin-mlir-code`, `define-rewrite-pattern` | as in Ch2 and Ch3 |
| The text form of `toy.cast` | `:assembly-format` | `` $input attr-dict `:` type($input) `to` type($output) ``, as in C++; it prints `toy.cast %0 : tensor<2xf64> to tensor<*xf64>` |
| The cast the inliner interface creates | `begin-mlir-code` inside the `materializeCallConversion` callback | the callback gets a builder; `with-current-OpBuilder` installs it |
| Inlining | MLIR's inliner pass (added to the `PassManager` in `toyc.sls`) | the dialect declares what the pass needs (`CallOpInterface`, a terminator trait, `DialectInlinerInterface`); no inliner is written in Scheme |
| Shape inference | `define-rewrite-pattern` (`shape-inference.sls`), applied by the greedy rewriter | one pattern per op; the C++ pass does it with an op interface; see [Why shape inference is written as patterns](#why-shape-inference-is-written-as-patterns) |

## Why shape inference is written as patterns

The C++ tutorial writes shape inference as a method of each op, `inferShapes`, behind an op interface, and a pass with
its own worklist that calls the method (`ShapeInferenceInterface.td`, `Dialect.cpp`, `ShapeInferencePass.cpp`). Its
reason is stated in the tutorial: express a transformation as generically as possible, so that other dialects can use it.
`shape-inference.sls` writes the same as one rewrite pattern for each op, and MLIR's greedy rewriter is the worklist.
Here they are, op to op. The titles of the tables are permalinks, with the lines of the code: the C++ files at the commit
of LLVM they were taken from (`392dfff97d29`), and `shape-inference.sls` at the commit `2505012c4bec` of this repository. A later
change to `shape-inference.sls` does not move them.

### `toy.add`

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/mlir/Dialect.cpp#L254">C++ (<code>Dialect.cpp</code>, L254)</a></th><th><a href="https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/shape-inference.sls#L37-L45">CREST DSL (<code>shape-inference.sls</code>, L37-L45)</a></th></tr>
<tr><td>

```cpp
void AddOp::inferShapes() { getResult().setType(getLhs().getType()); }
```

</td><td>

```scheme
(define-rewrite-pattern (%%infer-add op rewriter)
  :if-match
    %sum = toy.add (%lhs %rhs)
      :where (and (%%ranked? %lhs) (%%ranked? %rhs) (not (%%ranked? %sum)))
  :then-let
    ([!type (mlir::Value::getType %lhs)]
     [loc   (mlir::Operation::getLoc op)])
  :rewrite %sum :with
    result = toy.add (%lhs %rhs) :loc loc -> !type)
```

</td></tr>
</table>

The C++ method sets the type of the result in place, and nothing in it says when it may run: the pass decides that. The
DSL pattern says it. It applies to a `toy.add` whose operands are ranked and whose result is not (`:where`), and its
rewrite is the same op with the type of the left operand.

### `toy.mul`

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/mlir/Dialect.cpp#L369">C++ (<code>Dialect.cpp</code>, L369)</a></th><th><a href="https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/shape-inference.sls#L47-L55">CREST DSL (<code>shape-inference.sls</code>, L47-L55)</a></th></tr>
<tr><td>

```cpp
void MulOp::inferShapes() { getResult().setType(getLhs().getType()); }
```

</td><td>

```scheme
(define-rewrite-pattern (%%infer-mul op rewriter)
  :if-match
    %product = toy.mul (%lhs %rhs)
      :where (and (%%ranked? %lhs) (%%ranked? %rhs) (not (%%ranked? %product)))
  :then-let
    ([!type (mlir::Value::getType %lhs)]
     [loc   (mlir::Operation::getLoc op)])
  :rewrite %product :with
    result = toy.mul (%lhs %rhs) :loc loc -> !type)
```

</td></tr>
</table>

The same as `toy.add`.

### `toy.cast`

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/mlir/Dialect.cpp#L262">C++ (<code>Dialect.cpp</code>, L262)</a></th><th><a href="https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/shape-inference.sls#L57-L65">CREST DSL (<code>shape-inference.sls</code>, L57-L65)</a></th></tr>
<tr><td>

```cpp
void CastOp::inferShapes() { getResult().setType(getInput().getType()); }
```

</td><td>

```scheme
(define-rewrite-pattern (%%infer-cast op rewriter)
  :if-match
    %out = toy.cast (%in)
      :where (and (%%ranked? %in) (not (%%ranked? %out)))
  :then-let
    ([!type (mlir::Value::getType %in)]
     [loc   (mlir::Operation::getLoc op)])
  :rewrite %out :with
    result = toy.cast (%in) :loc loc -> !type)
```

</td></tr>
</table>

The cast gets the type of its input. After that it maps a type to the same type, and its folder removes it. The C++
tutorial gives the cast `CastOpInterface`, which folds identity casts. In this pipeline the removal already happens in
the shape inference pass: the greedy rewriter that applies the patterns also folds. With the folder of the cast taken
out, the casts stay after shape inference.

### `toy.transpose`

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/mlir/Dialect.cpp#L419-L423">C++ (<code>Dialect.cpp</code>, L419-L423)</a></th><th><a href="https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/shape-inference.sls#L67-L78">CREST DSL (<code>shape-inference.sls</code>, L67-L78)</a></th></tr>
<tr><td>

```cpp
void TransposeOp::inferShapes() {
  auto arrayTy = llvm::cast<RankedTensorType>(getOperand().getType());
  SmallVector<int64_t, 2> dims(llvm::reverse(arrayTy.getShape()));
  getResult().setType(RankedTensorType::get(dims, arrayTy.getElementType()));
}
```

</td><td>

```scheme
(define-rewrite-pattern (%%infer-transpose op rewriter)
  :if-match
    %out = toy.transpose (%in)
      :where (and (%%ranked? %in) (not (%%ranked? %out)))
  :then-let
    ([input-type (mlir::Value::getType %in)]
     [!type      (mlir::RankedTensorType::get
                  (reverse (mlir::RankedTensorType::getShape input-type))
                  (mlir::RankedTensorType::getElementType input-type))]
     [loc        (mlir::Operation::getLoc op)])
  :rewrite %out :with
    result = toy.transpose (%in) :loc loc -> !type)
```

</td></tr>
</table>

The computation is the same: the shape of the input, reversed. The C++ method casts the operand type to
`RankedTensorType`, which is only safe because the pass runs it when all operands are ranked. In the DSL the pattern
checks it itself (`:where`), and the computation is named steps in `:then-let`.

### Registering the rules

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/include/toy/ShapeInferenceInterface.td#L18-L28">C++, description left out (<code>ShapeInferenceInterface.td</code>, L18-L28)</a></th><th><a href="https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/shape-inference.sls#L81-L85">CREST DSL (<code>shape-inference.sls</code>, L81-L85)</a></th></tr>
<tr><td>

```tablegen
def ShapeInferenceOpInterface : OpInterface<"ShapeInference"> {
  let methods = [
    InterfaceMethod<"Infer and set the output shape for the current operation.",
                    "void", "inferShapes">
  ];
}
```

and, in `Ops.td`, on each of the four ops (here `AddOp`):

```tablegen
def AddOp : Toy_Op<"add",
    [Pure, DeclareOpInterfaceMethods<ShapeInferenceOpInterface>]> {
```

</td><td>

```scheme
(define-pattern-set toy:add-shape-inference-patterns!
  ("toy.add" %%infer-add 1)
  ("toy.mul" %%infer-mul 1)
  ("toy.cast" %%infer-cast 1)
  ("toy.transpose" %%infer-transpose 1))
```

</td></tr>
</table>

In C++ the rules are one interface, and every op that can be inferred declares it (`Ops.td` has it on `AddOp`,
`CastOp`, `MulOp` and `TransposeOp`). The pass asks each op through the interface, and an op without it is an error,
`unable to infer shape of operation without shape inference interface`. In the DSL the rules are a table of
(op name, pattern, benefit), and an op without a pattern stays unranked, which the check at the end of the pass reports.
The interface puts the knowledge in the op, where any pass can ask for it. The table puts it in one library, by op name.

### The pass

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch4/mlir/ShapeInferencePass.cpp#L55-L117">C++ (<code>ShapeInferencePass.cpp</code>, L55-L117)</a></th><th><a href="https://github.com/wcy123/crest/blob/2505012c4bec4947a32e74c02d2873f1b7780e6a/samples/toy/ch4/shape-inference.sls#L89-L107">CREST DSL (<code>shape-inference.sls</code>, L89-L107)</a></th></tr>
<tr><td>

```cpp
struct ShapeInferencePass
    : public mlir::PassWrapper<ShapeInferencePass, OperationPass<toy::FuncOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(ShapeInferencePass)
  StringRef getArgument() const override { return "toy-shape-inference"; }

  void runOnOperation() override {
    auto f = getOperation();

    llvm::SmallPtrSet<mlir::Operation *, 16> opWorklist;
    f.walk([&](mlir::Operation *op) {
      if (returnsDynamicShape(op))
        opWorklist.insert(op);
    });

    while (!opWorklist.empty()) {
      auto nextop = llvm::find_if(opWorklist, allOperandsInferred);
      if (nextop == opWorklist.end())
        break;

      Operation *op = *nextop;
      opWorklist.erase(op);

      LDBG() << "Inferring shape for: " << *op;
      if (auto shapeOp = dyn_cast<ShapeInference>(op)) {
        shapeOp.inferShapes();
      } else {
        op->emitError("unable to infer shape of operation without shape "
                      "inference interface");
        return signalPassFailure();
      }
    }

    if (!opWorklist.empty()) {
      f.emitError("Shape inference failed, ")
          << opWorklist.size() << " operations couldn't be inferred\n";
      signalPassFailure();
    }
  }

  static bool allOperandsInferred(Operation *op) {
    return llvm::all_of(op->getOperandTypes(), [](Type operandType) {
      return llvm::isa<RankedTensorType>(operandType);
    });
  }

  static bool returnsDynamicShape(Operation *op) {
    return llvm::any_of(op->getResultTypes(), [](Type resultType) {
      return !llvm::isa<RankedTensorType>(resultType);
    });
  }
};
```

</td><td>

```scheme
(define-pass (toy:shape-inference-pass func)
  (let ([ctx (mlir::Operation::getContext func)]
        [remaining 0])
    (with-current-MLIRContext ctx
      (apply-patterns func ctx :populate toy:add-shape-inference-patterns!))
    (mlir::Operation::walk
     func
     (lambda (op)
       (when (let loop ([i 0])
               (and (< i (mlir::Operation::getNumResults op))
                    (or (not (%%ranked? (mlir::Operation::getResult op i)))
                        (loop (+ i 1)))))
         (set! remaining (+ remaining 1))) mlir::WalkResult::advance))
    (or (zero? remaining)
        (begin
          (mlir::Operation::emitError
           func (string-append "Shape inference failed, " (number->string remaining)
                               " operations couldn't be inferred\n"))
          #f))))
```

</td></tr>
</table>

The C++ pass is the algorithm: collect the ops that return a dynamic shape, pick one whose operands are all inferred,
ask it through the interface, repeat, and report the ones left. In the DSL `apply-patterns` runs the patterns until
nothing changes, which is that loop, and what is left in the pass is the last step: count the ops that are still
unranked and report them. The message is the same.

### What this adds up to

- **A rule is a declaration.** It says when it applies and what the op becomes. The loop and the order are not
  written: the greedy rewriter repeats until nothing changes.
- **The condition is in the rule.** In C++ it is two functions of the pass, `allOperandsInferred` and
  `returnsDynamicShape`, that every op shares. Here each pattern has its own `:where`, next to the rewrite.
- **MLIR's own machinery is reused.** The pattern infrastructure runs the rules, and its folding removes the casts that
  became identity casts.
- **What the interface gives that this does not:** a pass that asks any op for its result shape, whatever the dialect,
  and the knowledge sits in the op. This chapter's patterns are specific to the four Toy ops, and a second dialect would
  write its own patterns.

## Related Documents

- [inlining.md](inlining.md) — step-by-step walkthrough of how MLIR's inliner
  calls `handleTerminator` on the dialect's interface, and why the callback is
  dialect-specific
- [../ch3/README.md](../ch3/README.md) — Ch3 canonicalization patterns that
  Ch4 inherits
