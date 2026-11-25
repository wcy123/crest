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

### `--emit=ast`

```sh
./toyc example.toy --emit=ast
```

```text
  Module:
    Function
      Proto 'multiply_transpose' @example.toy:0:1
      Params: [a, b]
      Block {
        Return
          BinOp: * @example.toy:1:23
            Call 'transpose' [ @example.toy:1:10
              var: a @example.toy:1:20
            ]
            Call 'transpose' [ @example.toy:1:25
              var: b @example.toy:1:35
            ]
      } // Block
    Function
      Proto 'main' @example.toy:4:1
      Params: []
      Block {
        VarDecl a<> @example.toy:5:3
          Literal: <2,3>[ <3>[ 1, 2, 3], <3>[ 4, 5, 6]] @example.toy:5:11
        VarDecl b<2,3> @example.toy:6:3
          Literal: <6>[ 1, 2, 3, 4, 5, 6] @example.toy:6:17
        VarDecl c<> @example.toy:7:3
          Call 'multiply_transpose' [ @example.toy:7:11
            var: a @example.toy:7:30
            var: b @example.toy:7:33
          ]
        VarDecl d<> @example.toy:8:3
          Call 'multiply_transpose' [ @example.toy:8:11
            var: b @example.toy:8:30
            var: a @example.toy:8:33
          ]
        VarDecl e<> @example.toy:9:3
          Call 'multiply_transpose' [ @example.toy:9:11
            var: c @example.toy:9:30
            var: d @example.toy:9:33
          ]
        VarDecl f<> @example.toy:10:3
          Call 'multiply_transpose' [ @example.toy:10:11
            var: a @example.toy:10:30
            var: c @example.toy:10:33
          ]
        Print [ @example.toy:11:3
          var: e @example.toy:11:9
        ]
      } // Block
```

The tree the parser makes, with nothing about MLIR yet. `--opt` changes nothing here. `var a<>` has no declared shape,
and `var b<2,3>` has one.

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

1. **A generic pass asks through interfaces.** The inliner works on any dialect, so it does not look at `toy.*` ops.
   An op interface says what an op is: `CallOpInterface` on `toy.generic_call` (the callee and the argument operands)
   and `CallableOpInterface` on `toy.func` (the body and the types). A dialect interface says what the dialect
   allows: `DialectInlinerInterface`. They are the `:interfaces` clauses in `toy.sls`; in C++ they are
   `DeclareOpInterfaceMethods<CallOpInterface>` in `Ops.td` and `ToyInlinerInterface` in `Dialect.cpp`.
2. **Inlining can make a type mismatch, and the dialect repairs it.** The callee takes `tensor<*xf64>` and the caller
   passes a ranked tensor. The inliner calls `materializeCallConversion`, which creates a `toy.cast`, and
   `handleTerminator`, which replaces the results of the call by the operands of the cloned `toy.return`.
   [inlining.md](inlining.md) walks through it.
3. **An op can exist only to bridge one step of a pipeline.** `toy.cast` has the traits `pure` and
   `same-operands-and-result-shape`. When shape inference has given the types, the cast changes nothing, and its folder
   (`:fold`) removes it.
4. **Shape inference is a rewrite to a fixed point.** Each pattern gives an op with an unranked result a precise type
   when its operands are ranked, and the greedy rewriter repeats until nothing changes (`shape-inference.sls`). The C++
   tutorial writes the same with an op interface (`ShapeInferenceOpInterface`) and a pass with a worklist.
5. **The order of the passes matters.** A `PassManager` runs the inliner on the module and the other passes nested on
   `toy.func`: inline, then shape inference, then canonicalize and CSE (`toyc.sls`; `toyc.cpp` in C++). Each pass needs
   what the one before made: after inlining the transpositions are in one function, so canonicalization can remove
   them. CSE merges equal ops, which is safe for ops marked `pure`.

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
| Shape inference | `define-rewrite-pattern` (`shape-inference.sls`), applied by the greedy rewriter | one pattern per op; the C++ pass does it with an op interface |

## Related Documents

- [inlining.md](inlining.md) — step-by-step walkthrough of how MLIR's inliner
  calls `handleTerminator` on the dialect's interface, and why the callback is
  dialect-specific
- [../ch3/README.md](../ch3/README.md) — Ch3 canonicalization patterns that
  Ch4 inherits
