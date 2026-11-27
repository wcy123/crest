# Toy Ch5 — Partial Lowering to Affine Dialects

Ch5 adds `--emit=mlir-affine`, which partially lowers the Toy dialect to a combination of `affine`, `arith`, `memref`
and `func` dialects. The lowering is MLIR's dialect conversion framework: a conversion target says what is legal, and
conversion patterns rewrite the ops that are not. Like Ch2 to Ch4, Ch5 needs LLVM 23.

## Try it

`example.toy` is the program of Ch4: `multiply_transpose` is called four times by `main`, which prints `e`.

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
the [Ch3 README](../ch3/README.md#commands). `--emit=ast`, `--emit=mlir` and `--emit=mlir --opt` work as in
[Ch1](../ch1/README.md#try-it) and [Ch4](../ch4/README.md#try-it), and the module that `--emit=mlir --opt` prints is the
one that the lowering starts from.

### `--emit=mlir-affine`

```sh
./toyc example.toy --emit=mlir-affine
```

```mlir
module {
  func.func @main() {
    %cst = arith.constant 6.000000e+00 : f64
    %cst_0 = arith.constant 5.000000e+00 : f64
    %cst_1 = arith.constant 4.000000e+00 : f64
    %cst_2 = arith.constant 3.000000e+00 : f64
    %cst_3 = arith.constant 2.000000e+00 : f64
    %cst_4 = arith.constant 1.000000e+00 : f64
    %alloc = memref.alloc() : memref<2x3xf64>
    %alloc_5 = memref.alloc() : memref<2x3xf64>
    %alloc_6 = memref.alloc() : memref<3x2xf64>
    %alloc_7 = memref.alloc() : memref<3x2xf64>
    %alloc_8 = memref.alloc() : memref<2x3xf64>
    affine.store %cst_4, %alloc_8[0, 0] : memref<2x3xf64>
    affine.store %cst_3, %alloc_8[0, 1] : memref<2x3xf64>
    affine.store %cst_2, %alloc_8[0, 2] : memref<2x3xf64>
    affine.store %cst_1, %alloc_8[1, 0] : memref<2x3xf64>
    affine.store %cst_0, %alloc_8[1, 1] : memref<2x3xf64>
    affine.store %cst, %alloc_8[1, 2] : memref<2x3xf64>
    affine.for %arg0 = 0 to 3 {
      affine.for %arg1 = 0 to 2 {
        %0 = affine.load %alloc_8[%arg1, %arg0] : memref<2x3xf64>
        affine.store %0, %alloc_7[%arg0, %arg1] : memref<3x2xf64>
      }
    }
    affine.for %arg0 = 0 to 3 {
      affine.for %arg1 = 0 to 2 {
        %0 = affine.load %alloc_7[%arg0, %arg1] : memref<3x2xf64>
        %1 = arith.mulf %0, %0 : f64
        affine.store %1, %alloc_6[%arg0, %arg1] : memref<3x2xf64>
      }
    }
    affine.for %arg0 = 0 to 2 {
      affine.for %arg1 = 0 to 3 {
        %0 = affine.load %alloc_6[%arg1, %arg0] : memref<3x2xf64>
        affine.store %0, %alloc_5[%arg0, %arg1] : memref<2x3xf64>
      }
    }
    affine.for %arg0 = 0 to 2 {
      affine.for %arg1 = 0 to 3 {
        %0 = affine.load %alloc_5[%arg0, %arg1] : memref<2x3xf64>
        %1 = arith.mulf %0, %0 : f64
        affine.store %1, %alloc[%arg0, %arg1] : memref<2x3xf64>
      }
    }
    toy.print %alloc : memref<2x3xf64>
    memref.dealloc %alloc_8 : memref<2x3xf64>
    memref.dealloc %alloc_7 : memref<3x2xf64>
    memref.dealloc %alloc_6 : memref<3x2xf64>
    memref.dealloc %alloc_5 : memref<2x3xf64>
    memref.dealloc %alloc : memref<2x3xf64>
    return
  }
}
```

The four Toy ops that compute (`toy.transpose`, `toy.mul`, `toy.transpose`, `toy.mul`) and the constant are now loops
and buffers:

- There is one `memref.alloc` for each tensor value, five in all, and the `memref.dealloc` of each is just before the
  `return`.
- The constant is stored one element at a time, `affine.store %cst_4, %alloc_8[0, 0]`, and the six `arith.constant` at the
  top are its elements.
- Each of the other four ops is an `affine.for` nest over the shape of its result. A `toy.transpose` loads with the two
  indices swapped, `%alloc_8[%arg1, %arg0]`. A `toy.mul` loads its operand, multiplies with `arith.mulf` and stores.
- `toy.print` is still a Toy op, now with a `memref` operand. The conversion is partial: this op is left for the lowering
  of Ch6. `toy.func` is a `func.func` and `toy.return` is a `return`.

### `--emit=mlir-affine --opt`

```sh
./toyc example.toy --emit=mlir-affine --opt
```

```mlir
module {
  func.func @main() {
    %cst = arith.constant 6.000000e+00 : f64
    %cst_0 = arith.constant 5.000000e+00 : f64
    %cst_1 = arith.constant 4.000000e+00 : f64
    %cst_2 = arith.constant 3.000000e+00 : f64
    %cst_3 = arith.constant 2.000000e+00 : f64
    %cst_4 = arith.constant 1.000000e+00 : f64
    %alloc = memref.alloc() : memref<2x3xf64>
    %alloc_5 = memref.alloc() : memref<2x3xf64>
    affine.store %cst_4, %alloc_5[0, 0] : memref<2x3xf64>
    affine.store %cst_3, %alloc_5[0, 1] : memref<2x3xf64>
    affine.store %cst_2, %alloc_5[0, 2] : memref<2x3xf64>
    affine.store %cst_1, %alloc_5[1, 0] : memref<2x3xf64>
    affine.store %cst_0, %alloc_5[1, 1] : memref<2x3xf64>
    affine.store %cst, %alloc_5[1, 2] : memref<2x3xf64>
    affine.for %arg0 = 0 to 2 {
      affine.for %arg1 = 0 to 3 {
        %0 = affine.load %alloc_5[%arg0, %arg1] : memref<2x3xf64>
        %1 = arith.mulf %0, %0 : f64
        %2 = arith.mulf %1, %1 : f64
        affine.store %2, %alloc[%arg0, %arg1] : memref<2x3xf64>
      }
    }
    toy.print %alloc : memref<2x3xf64>
    memref.dealloc %alloc_5 : memref<2x3xf64>
    memref.dealloc %alloc : memref<2x3xf64>
    return
  }
}
```

The four loop nests became one, and only two buffers are left: the one of the constant and the one of the result. The
values that went through the other buffers are now computed in the loop body, `%0`, `%1` and `%2`.

### What `--opt` changed

Diff the output without `--opt` and with it. The lines with `-` are removed and the lines with `+` are new.

```sh
opt-diff() { diff -u --label 'without --opt' --label 'with --opt' \
                   <(./toyc "$1" --emit=mlir-affine) <(./toyc "$1" --emit=mlir-affine --opt); }
opt-diff example.toy
```

```diff
--- without --opt
+++ with --opt
@@ -8,45 +8,21 @@
     %cst_4 = arith.constant 1.000000e+00 : f64
     %alloc = memref.alloc() : memref<2x3xf64>
     %alloc_5 = memref.alloc() : memref<2x3xf64>
-    %alloc_6 = memref.alloc() : memref<3x2xf64>
-    %alloc_7 = memref.alloc() : memref<3x2xf64>
-    %alloc_8 = memref.alloc() : memref<2x3xf64>
-    affine.store %cst_4, %alloc_8[0, 0] : memref<2x3xf64>
-    affine.store %cst_3, %alloc_8[0, 1] : memref<2x3xf64>
-    affine.store %cst_2, %alloc_8[0, 2] : memref<2x3xf64>
-    affine.store %cst_1, %alloc_8[1, 0] : memref<2x3xf64>
-    affine.store %cst_0, %alloc_8[1, 1] : memref<2x3xf64>
-    affine.store %cst, %alloc_8[1, 2] : memref<2x3xf64>
-    affine.for %arg0 = 0 to 3 {
-      affine.for %arg1 = 0 to 2 {
-        %0 = affine.load %alloc_8[%arg1, %arg0] : memref<2x3xf64>
-        affine.store %0, %alloc_7[%arg0, %arg1] : memref<3x2xf64>
-      }
-    }
-    affine.for %arg0 = 0 to 3 {
-      affine.for %arg1 = 0 to 2 {
-        %0 = affine.load %alloc_7[%arg0, %arg1] : memref<3x2xf64>
-        %1 = arith.mulf %0, %0 : f64
-        affine.store %1, %alloc_6[%arg0, %arg1] : memref<3x2xf64>
-      }
-    }
-    affine.for %arg0 = 0 to 2 {
-      affine.for %arg1 = 0 to 3 {
-        %0 = affine.load %alloc_6[%arg1, %arg0] : memref<3x2xf64>
-        affine.store %0, %alloc_5[%arg0, %arg1] : memref<2x3xf64>
-      }
-    }
+    affine.store %cst_4, %alloc_5[0, 0] : memref<2x3xf64>
+    affine.store %cst_3, %alloc_5[0, 1] : memref<2x3xf64>
+    affine.store %cst_2, %alloc_5[0, 2] : memref<2x3xf64>
+    affine.store %cst_1, %alloc_5[1, 0] : memref<2x3xf64>
+    affine.store %cst_0, %alloc_5[1, 1] : memref<2x3xf64>
+    affine.store %cst, %alloc_5[1, 2] : memref<2x3xf64>
     affine.for %arg0 = 0 to 2 {
       affine.for %arg1 = 0 to 3 {
         %0 = affine.load %alloc_5[%arg0, %arg1] : memref<2x3xf64>
         %1 = arith.mulf %0, %0 : f64
-        affine.store %1, %alloc[%arg0, %arg1] : memref<2x3xf64>
+        %2 = arith.mulf %1, %1 : f64
+        affine.store %2, %alloc[%arg0, %arg1] : memref<2x3xf64>
       }
     }
     toy.print %alloc : memref<2x3xf64>
-    memref.dealloc %alloc_8 : memref<2x3xf64>
-    memref.dealloc %alloc_7 : memref<3x2xf64>
-    memref.dealloc %alloc_6 : memref<3x2xf64>
     memref.dealloc %alloc_5 : memref<2x3xf64>
     memref.dealloc %alloc : memref<2x3xf64>
     return
```

The loops are fused by `createLoopFusionPass`. `createAffineScalarReplacementPass` forwards a stored value to the load
that reads it, and eliminates a buffer when all its accesses are forwarded, which is what happened to the temporary
buffers. Both work on `affine` ops, and the lowering of this chapter is what gives them those.

### Take one pass out

Delete one line of `%%run-pipeline!` in `toyc.sls` and run `./toyc example.toy --emit=mlir-affine --opt` again:

| Line removed | What you see |
|---|---|
| `(toy:lower-to-affine-pass)` | the module stays in the Toy dialect: `toy.transpose`, `toy.mul` and `toy.print`, with no `affine.for` and no `memref.alloc` |
| `(mlir::affine::createLoopFusionPass)` | four loop nests and five `memref.alloc`, instead of one and two |
| `(mlir::affine::createAffineScalarReplacementPass)` | one fused loop nest, but five `memref.alloc` and four `affine.load`, instead of two and one: the temporary buffers stay |
| `(mlir::createCanonicalizerPass)` after the lowering, the one in the `func.func` part | nine `arith.constant` instead of six, and stores like `%alloc_0[%c0, %c0]` instead of `[0, 0]`: the index constants are not folded into the subscripts, and each float constant stays beside its store instead of moving to the top |
| `(mlir::createCSEPass)` after the lowering | the same output: this program does not need it |

### One pattern at a time

Each lowering pattern has a test that fails without it. `example.toy` has most of the ops. `add.toy` is the program that
has a `toy.add`:

```text
def main() {
  var a<2, 3> = [1, 2, 3, 4, 5, 6];
  var b<2, 3> = [6, 5, 4, 3, 2, 1];
  var c = a + b;
  print(c);
}
```

```sh
./toyc add.toy --emit=mlir-affine
```

```mlir
module {
  func.func @main() {
    %cst = arith.constant 6.000000e+00 : f64
    %cst_0 = arith.constant 5.000000e+00 : f64
    %cst_1 = arith.constant 4.000000e+00 : f64
    %cst_2 = arith.constant 3.000000e+00 : f64
    %cst_3 = arith.constant 2.000000e+00 : f64
    %cst_4 = arith.constant 1.000000e+00 : f64
    %alloc = memref.alloc() : memref<2x3xf64>
    %alloc_5 = memref.alloc() : memref<2x3xf64>
    %alloc_6 = memref.alloc() : memref<2x3xf64>
    affine.store %cst_4, %alloc_6[0, 0] : memref<2x3xf64>
    affine.store %cst_3, %alloc_6[0, 1] : memref<2x3xf64>
    affine.store %cst_2, %alloc_6[0, 2] : memref<2x3xf64>
    affine.store %cst_1, %alloc_6[1, 0] : memref<2x3xf64>
    affine.store %cst_0, %alloc_6[1, 1] : memref<2x3xf64>
    affine.store %cst, %alloc_6[1, 2] : memref<2x3xf64>
    affine.store %cst, %alloc_5[0, 0] : memref<2x3xf64>
    affine.store %cst_0, %alloc_5[0, 1] : memref<2x3xf64>
    affine.store %cst_1, %alloc_5[0, 2] : memref<2x3xf64>
    affine.store %cst_2, %alloc_5[1, 0] : memref<2x3xf64>
    affine.store %cst_3, %alloc_5[1, 1] : memref<2x3xf64>
    affine.store %cst_4, %alloc_5[1, 2] : memref<2x3xf64>
    affine.for %arg0 = 0 to 2 {
      affine.for %arg1 = 0 to 3 {
        %0 = affine.load %alloc_6[%arg0, %arg1] : memref<2x3xf64>
        %1 = affine.load %alloc_5[%arg0, %arg1] : memref<2x3xf64>
        %2 = arith.addf %0, %1 : f64
        affine.store %2, %alloc[%arg0, %arg1] : memref<2x3xf64>
      }
    }
    toy.print %alloc : memref<2x3xf64>
    memref.dealloc %alloc_6 : memref<2x3xf64>
    memref.dealloc %alloc_5 : memref<2x3xf64>
    memref.dealloc %alloc : memref<2x3xf64>
    return
  }
}
```

The nest loads the left operand, then the right one, adds them with `arith.addf` and stores the sum. `--opt` gives the
same output: there is one loop nest, so nothing to fuse and no temporary buffer to remove.

| Pattern | Program | Tests that fail when it is switched off |
|---|---|---|
| `toy.constant`, `toy.func`, `toy.return`, `toy.print` | every program | `action-mlir-affine-add.mlir`, `action-mlir-affine-example.mlir` and `action-mlir-affine-opt-example.mlir` |
| `toy.add` | `add.toy` | `action-mlir-affine-add.mlir`, and no other |
| `toy.mul` | `example.toy` | `action-mlir-affine-example.mlir`, `action-mlir-affine-opt-example.mlir` |
| `toy.transpose` | `example.toy` | the same two, and `lowering-failure.mlir` |

Two more tests check that a lowering that cannot finish fails. `lowering-main-arguments.mlir` has a `main` with an
argument: only a `main` without arguments or results is lowered, so the `toy.func` stays and the conversion reports
`failed to legalize operation 'toy.func'`. `lowering-failure.mlir` has a `toy.reshape` of a value that is not a constant,
which has no lowering in Ch5, so `toy.reshape` stays and the conversion fails the same way. In both cases `toyc` exits
with status 4, as the C++ `toyc` does when its pass manager fails.

## What you learn about MLIR here

Ch4 was about passes that know nothing about Toy. Ch5 changes the abstraction level: the Toy ops become `affine`,
`arith`, `memref` and `func` ops, and MLIR's dialect conversion framework drives it.

The links are permalinks: the Scheme files of this chapter at the commit `c75cc9c762d2` of this repository, and the C++ files of
the LLVM Toy tutorial at the commit `392dfff97d29` of LLVM.

1. **A conversion says what is legal, what is not, and rewrites until only legal ops remain.** The conversion target
   has `affine`, `arith`, `func`, `memref` and `builtin` legal, and the `toy` dialect illegal. `toy.print` is legal only
   when no operand is a tensor, so it is rewritten once its operand is a `memref`. The conversion is partial: ops that
   stay legal are left alone, and `toy.print` stays for Ch6.
   - Scheme: [`apply-conversion` (`lower-to-affine.sls` L268-L291)](https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L268-L291), [the pass (`lower-to-affine.sls` L294-L297)](https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L294-L297)
   - C++: [the pass, the target and `applyPartialConversion` (`LowerToAffineLoops.cpp` L312-L362)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L312-L362)
2. **A conversion pattern sees its operands already converted, and replaces an op that makes a tensor by the buffer
   that holds it.** In C++ the operands come from the `OpAdaptor` (`adaptor.getLhs()`), and the pattern ends with
   `replaceOp(op, alloc)`. In the DSL the names of the match, `%lhs` and `%in`, are the converted operands, and the
   `:rewrite` clause ends with the `alloc`.
   - Scheme: [`toy.add` and `toy.mul` (`lower-to-affine.sls` L173-L199)](https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L173-L199), [`toy.transpose` (`lower-to-affine.sls` L205-L218)](https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L205-L218)
   - C++: [`BinaryOpLowering` (`LowerToAffineLoops.cpp` L113-L138)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L113-L138), [`TransposeOpLowering` (`LowerToAffineLoops.cpp` L283-L300)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L283-L300)
3. **Tensors have values, buffers have lifetimes, and the lowering must allocate and free them.** Each result gets a
   `memref.alloc` at the start of the block, and a `memref.dealloc` before the terminator.
   - Scheme: [`%%insert-alloc-and-dealloc!` (`lower-to-affine.sls` L75-L88)](https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L75-L88)
   - C++: [`insertAllocAndDealloc` (`LowerToAffineLoops.cpp` L56-L69)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L56-L69)
4. **An elementwise tensor op becomes a loop nest over its shape.** One `affine.for` for each dimension, with
   `affine.load` and `affine.store` whose subscripts are the loop indices. A transposition swaps the indices of the
   load.
   - Scheme: [`%%emit-loop-nest!` and `%%lower-op-to-loops!` (`lower-to-affine.sls` L93-L120)](https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L93-L120)
   - C++: [`lowerOpToLoops`, which calls `buildAffineLoopNest` (`LowerToAffineLoops.cpp` L75-L106)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L75-L106)
5. **Generic passes clean up after a lowering, and `affine` ops enable new ones.** Canonicalize and CSE on `func.func`
   fold the index constants into the subscripts and move the constants to the top. With `--opt`, loop fusion and affine
   scalar replacement merge the nests and remove the temporary buffers.
   - Scheme: [`%%run-pipeline!` (`toyc.sls` L112-L128)](https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/toyc.sls#L112-L128)
   - C++: [the pipeline (`toyc.cpp` L137-L166)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/toyc.cpp#L137-L166)
6. **A conversion that cannot legalize an op fails the pass.** The `toy.func` of a `main` with arguments, or a
   `toy.reshape`, stays illegal, and the conversion fails with `failed to legalize operation`.
   - Scheme: [`toy.func` (`lower-to-affine.sls` L226-L240)](https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L226-L240)
   - C++: [`FuncOpLowering` (`LowerToAffineLoops.cpp` L213-L238)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L213-L238)

## What's new over Ch4

| Feature | Ch4 | Ch5 |
|---|---|---|
| Actions | `ast`, `mlir` | `ast`, `mlir`, `mlir-affine` |
| `--emit=mlir-affine` | — | partial lowering to Affine+Arith+MemRef+Func |
| Post-lowering passes | — | canonicalize + CSE on `func.func` |
| `--opt` additions | canonicalize | + loop fusion + affine scalar replacement |

### Conversion patterns (`lower-to-affine.sls`)

| Source op | Target |
|---|---|
| `toy.constant` | `memref.alloc` + `affine.store` per element |
| `toy.add` | `affine.for` nest + `arith.addf` + `affine.store` |
| `toy.mul` | `affine.for` nest + `arith.mulf` + `affine.store` |
| `toy.transpose` | `affine.for` nest with reversed-index `affine.load` |
| `toy.func @main` | `func.func @main` (other functions are inlined) |
| `toy.return` | `func.return` (void only) |
| `toy.print` | operand update tensor → memref; op kept for later lowering |

Every pattern is a `define-conversion-pattern`, and every op it creates is a `begin-mlir-code`
form: `memref.alloc` and `memref.dealloc` (at the start and before the terminator of the
block, under an `InsertionGuard`), the `affine.for` nest with its bounds as `affine-map-attr`s and
each loop body a `{ ^body ... }` region, `affine.load` and `affine.store` with an identity map, and
`arith.constant`, `arith.addf` and `arith.mulf`. No typed builder is called. A pattern that
replaces its op with a value ends with that value, here the `memref.alloc`. The loop nest is
written out, rather than built by MLIR's `buildAffineLoopNest` callback API, so the whole
lowering reads as the IR it produces.

### `--emit=mlir-affine` pipeline (`toyc.sls`)

Steps 1 to 3 are Ch4's: the inliner, shape inference, and canonicalize + CSE on `toy.func`. Then:

4. **Partial lowering** — `toy:lower-to-affine-pass` (a `define-pass` around one `apply-conversion`)
5. **Canonicalize + CSE** — on `func.func` bodies
6. **(--opt only)** Loop fusion + affine scalar replacement on `func.func`

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect, `mlir-gen.sls`, the canonicalization patterns, shape inference, inlining | `define-dialect`, `begin-mlir-code`, `define-rewrite-pattern`, MLIR's inliner pass | as in Ch4 |
| The affine lowering of `toy.constant`, `toy.add`, `toy.mul`, `toy.transpose`, `toy.func`, `toy.return`, `toy.print` | `define-conversion-pattern`, with every op a `begin-mlir-code` form | see [Why the lowering is written as conversion patterns](#why-the-lowering-is-written-as-conversion-patterns) |
| Registering the conversion | `apply-conversion` (`:partial-mode`, `:converter`, `:legal-dialects`, `:illegal-dialects`, `:dynamically-legal`, `:patterns`) | one declaration instead of a type converter, a target and a pattern set created and freed by hand |
| Moving the body of `toy.func` into `func.func` | `(:move-region op)` | the region moves, it is not rebuilt |

## Why the lowering is written as conversion patterns

The C++ tutorial writes the lowering in `LowerToAffineLoops.cpp`: one `OpConversionPattern` struct for each op, helper
functions for the buffers and the loops, and a pass that builds a `ConversionTarget` and a `RewritePatternSet`. The
pipeline is in `toyc.cpp`. `lower-to-affine.sls` has the same pieces: one `define-conversion-pattern` for each op, the same
helpers as functions, and the pass is one `apply-conversion`. Here they are, piece to piece. The titles of the tables are
permalinks, with the lines of the code: the C++ files at the commit of LLVM they were taken from (`392dfff97d29`), and the
Scheme files at the commit `c75cc9c762d2` of this repository. A later change to the Scheme files does not move them.

### The pass and its conversion target

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L312-L362">C++, comments left out (<code>LowerToAffineLoops.cpp</code>, L312-L362)</a></th><th><a href="https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L268-L297">CREST DSL, comments left out (<code>lower-to-affine.sls</code>, L268-L297)</a></th></tr>
<tr><td>

```cpp
struct ToyToAffineLoweringPass
    : public PassWrapper<ToyToAffineLoweringPass, OperationPass<ModuleOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(ToyToAffineLoweringPass)
  StringRef getArgument() const override { return "toy-to-affine"; }

  void getDependentDialects(DialectRegistry &registry) const override {
    registry.insert<affine::AffineDialect, func::FuncDialect,
                    memref::MemRefDialect>();
  }
  void runOnOperation() final;
};
```

```cpp
void ToyToAffineLoweringPass::runOnOperation() {
  ConversionTarget target(getContext());

  target.addLegalDialect<affine::AffineDialect, BuiltinDialect,
                         arith::ArithDialect, func::FuncDialect,
                         memref::MemRefDialect>();

  target.addIllegalDialect<toy::ToyDialect>();
  target.addDynamicallyLegalOp<toy::PrintOp>([](toy::PrintOp op) {
    return llvm::none_of(op->getOperandTypes(),
                         [](Type type) { return llvm::isa<TensorType>(type); });
  });

  RewritePatternSet patterns(&getContext());
  patterns.add<AddOpLowering, ConstantOpLowering, FuncOpLowering, MulOpLowering,
               PrintOpLowering, ReturnOpLowering, TransposeOpLowering>(
      &getContext());

  if (failed(
          applyPartialConversion(getOperation(), target, std::move(patterns))))
    signalPassFailure();
}
```

</td><td>

```scheme
(define (%%toy-to-affine-lower! module-op ctx)
  (apply-conversion module-op ctx
                    :partial-mode
                    :converter (with-TypeConverter type-converter
                                 :conversions ((lambda (type)
                                                 (if (mlir::isa<RankedTensorType>? type)
                                                     (%%tensor->memref-type type)
                                                     type))))
                    :legal-dialects ("affine" "arith" "func" "memref" "builtin")
                    :illegal-dialects ("toy")
                    :dynamically-legal (("toy.print"
                                         (lambda (print-op)
                                           (not (mlir::isa<TensorType>?
                                                 (mlir::Value::getType
                                                  (mlir::Operation::getOperand print-op 0)))))))
                    :patterns (("toy.constant"  %%constant-lower!)
                               ("toy.add"       %%add-lower!)
                               ("toy.mul"       %%mul-lower!)
                               ("toy.transpose" %%transpose-lower!)
                               ("toy.func"      %%func-lower!)
                               ("toy.return"    %%return-lower!)
                               ("toy.print"     %%print-lower!))))
```

```scheme
(define-pass (toy:lower-to-affine-pass module)
  (let ([ctx (mlir::Operation::getContext module)])
    (with-current-MLIRContext ctx
      (%%toy-to-affine-lower! module ctx))))
```

</td></tr>
</table>

Both say the same four things: which dialects are legal, that `toy` is illegal, that `toy.print` is legal only when its
operand is no longer a tensor, and the patterns. C++ says them with a `ConversionTarget`, three calls on it, a
`RewritePatternSet` and `applyPartialConversion`. The DSL says them as keys of one `apply-conversion` form, and the pass
has nothing else in it. The C++ pass also lists the dialects it creates ops of (`getDependentDialects`); the DSL inserts
them where `toyc.sls` builds the context.

### Buffers

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L56-L69">C++, comments left out (<code>LowerToAffineLoops.cpp</code>, L56-L69)</a></th><th><a href="https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L75-L88">CREST DSL, comments left out (<code>lower-to-affine.sls</code>, L75-L88)</a></th></tr>
<tr><td>

```cpp
static Value insertAllocAndDealloc(MemRefType type, Location loc,
                                   PatternRewriter &rewriter) {
  auto alloc = memref::AllocOp::create(rewriter, loc, type);

  auto *parentBlock = alloc->getBlock();
  alloc->moveBefore(&parentBlock->front());

  auto dealloc = memref::DeallocOp::create(rewriter, loc, alloc);
  dealloc->moveBefore(&parentBlock->back());
  return alloc;
}
```

</td><td>

```scheme
(define (%%insert-alloc-and-dealloc! rw loc memref-type block)
  (let ([alloc (with-InsertionGuard guard (rw)
                                    (mlir::RewriterBase::setInsertionPoint rw (mlir::Block::front block))
                                    (with-current-OpBuilder rw
                                      (begin-mlir-code
                                          a = memref.alloc ()
                                          (operandSegmentSizes : '(0 0) :i32-array)
                                          :loc loc -> memref-type)))])
    (with-InsertionGuard guard (rw)
                         (mlir::RewriterBase::setInsertionPoint rw (mlir::Block::back block))
                         (with-current-OpBuilder rw
                           (begin-mlir-code
                               memref.dealloc (alloc) :loc loc)))
    alloc))
```

</td></tr>
</table>

Both leave the `memref.alloc` at the start of the block and the `memref.dealloc` before its terminator. C++ creates each
op where the rewriter is, then moves it (`moveBefore`). The DSL moves the insertion point first, to the front or to the
end of the block, and creates the op there; `with-InsertionGuard` puts the insertion point back afterwards.

### The loop nest

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L75-L106">C++, comments left out (<code>LowerToAffineLoops.cpp</code>, L75-L106)</a></th><th><a href="https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L93-L120">CREST DSL, comments left out (<code>lower-to-affine.sls</code>, L93-L120)</a></th></tr>
<tr><td>

```cpp
using LoopIterationFn =
    function_ref<Value(OpBuilder &rewriter, ValueRange loopIvs)>;
```

```cpp
static void lowerOpToLoops(Operation *op, PatternRewriter &rewriter,
                           LoopIterationFn processIteration) {
  auto tensorType = llvm::cast<RankedTensorType>((*op->result_type_begin()));
  auto loc = op->getLoc();

  auto memRefType = convertTensorToMemRef(tensorType);
  auto alloc = insertAllocAndDealloc(memRefType, loc, rewriter);

  SmallVector<int64_t, 4> lowerBounds(tensorType.getRank(), /*Value=*/0);
  SmallVector<int64_t, 4> steps(tensorType.getRank(), /*Value=*/1);
  affine::buildAffineLoopNest(
      rewriter, loc, lowerBounds, tensorType.getShape(), steps,
      [&](OpBuilder &nestedBuilder, Location loc, ValueRange ivs) {
        Value valueToStore = processIteration(nestedBuilder, ivs);
        affine::AffineStoreOp::create(nestedBuilder, loc, valueToStore, alloc,
                                      ivs);
      });

  rewriter.replaceOp(op, alloc);
}
```

</td><td>

```scheme
(define (%%emit-loop-nest! loc ctx shape alloc body-fn)
  (let ([idx (mlir::IndexType::get ctx)])
    (let nest ([dims shape] [ivs '()])
      (if (null? dims)
          (let ([val (body-fn (reverse ivs))]
                [map (%%identity-map-attr (length ivs))])
            (begin-mlir-code
                affine.store (val alloc ,@(reverse ivs)) (map : map) :loc loc))
          (begin-mlir-code
              affine.for ()
              (lowerBoundMap : (affine-map-attr () () 0))
              (upperBoundMap : (affine-map-attr () () (car dims)))
              (step : 1 :index)
              { ^body ,@(list idx)
                (nest (cdr dims) (cons (:arg 0) ivs))
                affine.yield () :loc loc }
              :loc loc)))))
```

```scheme
(define (%%lower-op-to-loops! op rw tensor-type body-fn)
  (let* ([loc         (mlir::Operation::getLoc op)]
         [ctx         (mlir::Operation::getContext op)]
         [memref-type (%%tensor->memref-type tensor-type)]
         [alloc       (%%insert-alloc-and-dealloc! rw loc memref-type (mlir::Operation::getBlock op))])
    (with-current-OpBuilder rw
      (%%emit-loop-nest! loc ctx (mlir::RankedTensorType::getShape tensor-type) alloc body-fn))
    alloc))
```

</td></tr>
</table>

C++ asks MLIR's `buildAffineLoopNest` for the nest and gives it a function for the body. The DSL writes the nest out: each
`affine.for` has its bound maps and its step, its body is a `{ ^body ... }` region, and the innermost body stores the value.
It says what `buildAffineLoopNest` hides, and the lowering reads as the IR it produces. The DSL could call
`buildAffineLoopNest` as well, through a Scheme macro that takes a procedure; this chapter chose to write the nest out.

### `toy.add` and `toy.mul`

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L113-L138">C++, comments left out (<code>LowerToAffineLoops.cpp</code>, L113-L138)</a></th><th><a href="https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L173-L199">CREST DSL, comments left out (<code>lower-to-affine.sls</code>, L173-L199)</a></th></tr>
<tr><td>

```cpp
template <typename BinaryOp, typename LoweredBinaryOp>
struct BinaryOpLowering : public OpConversionPattern<BinaryOp> {
  using OpConversionPattern<BinaryOp>::OpConversionPattern;
  using OpAdaptor = typename OpConversionPattern<BinaryOp>::OpAdaptor;

  LogicalResult
  matchAndRewrite(BinaryOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const final {
    auto loc = op->getLoc();
    lowerOpToLoops(op, rewriter, [&](OpBuilder &builder, ValueRange loopIvs) {
      auto loadedLhs =
          affine::AffineLoadOp::create(builder, loc, adaptor.getLhs(), loopIvs);
      auto loadedRhs =
          affine::AffineLoadOp::create(builder, loc, adaptor.getRhs(), loopIvs);

      return LoweredBinaryOp::create(builder, loc, loadedLhs, loadedRhs);
    });
    return success();
  }
};
using AddOpLowering = BinaryOpLowering<toy::AddOp, arith::AddFOp>;
using MulOpLowering = BinaryOpLowering<toy::MulOp, arith::MulFOp>;
```

</td><td>

```scheme
(define (%%binary-lower! op rw lhs rhs kind)
  (let* ([tensor-type (mlir::Value::getType (mlir::Operation::getResult op 0))]
         [elem-type   (mlir::RankedTensorType::getElementType tensor-type)]
         [loc         (mlir::Operation::getLoc op)])
    (%%lower-op-to-loops!
     op rw tensor-type
     (lambda (ivs)
       (let ([map (%%identity-map-attr (length ivs))])
         (begin-mlir-code
             l = affine.load (lhs ,@ivs) (map : map) :loc loc -> elem-type
             r = affine.load (rhs ,@ivs) (map : map) :loc loc -> elem-type
             (case kind
               [(add) (begin-mlir-code v = arith.addf (l r) :loc loc)]
               [(mul) (begin-mlir-code v = arith.mulf (l r) :loc loc)])))))))
```

```scheme
(define-conversion-pattern (%%add-lower! op operands-ref rw tc)
  :if-match
    %sum = toy.add (%lhs %rhs)
  :rewrite %sum :with
    (%%binary-lower! op rw %lhs %rhs 'add))
```

```scheme
(define-conversion-pattern (%%mul-lower! op operands-ref rw tc)
  :if-match
    %product = toy.mul (%lhs %rhs)
  :rewrite %product :with
    (%%binary-lower! op rw %lhs %rhs 'mul))
```

</td></tr>
</table>

C++ shares the code of the two with a template over the Toy op and the `arith` op. The DSL shares it with a function and
a symbol, `'add` or `'mul`, and each pattern says its own match, `%sum = toy.add (%lhs %rhs)`. Both load the left operand
first.

### `toy.constant`

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L144-L207">C++, comments left out (<code>LowerToAffineLoops.cpp</code>, L144-L207)</a></th><th><a href="https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L128-L165">CREST DSL, comments left out (<code>lower-to-affine.sls</code>, L128-L165)</a></th></tr>
<tr><td>

```cpp
struct ConstantOpLowering : public OpConversionPattern<toy::ConstantOp> {
  using OpConversionPattern<toy::ConstantOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(toy::ConstantOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const final {
    DenseElementsAttr constantValue = op.getValue();
    Location loc = op.getLoc();

    auto tensorType = llvm::cast<RankedTensorType>(op.getType());
    auto memRefType = convertTensorToMemRef(tensorType);
    auto alloc = insertAllocAndDealloc(memRefType, loc, rewriter);

    auto valueShape = memRefType.getShape();
    SmallVector<Value, 8> constantIndices;

    if (!valueShape.empty()) {
      for (auto i : llvm::seq<int64_t>(0, *llvm::max_element(valueShape)))
        constantIndices.push_back(
            arith::ConstantIndexOp::create(rewriter, loc, i));
    } else {
      constantIndices.push_back(
          arith::ConstantIndexOp::create(rewriter, loc, 0));
    }

    SmallVector<Value, 2> indices;
    auto valueIt = constantValue.value_begin<FloatAttr>();
    std::function<void(uint64_t)> storeElements = [&](uint64_t dimension) {
      if (dimension == valueShape.size()) {
        affine::AffineStoreOp::create(
            rewriter, loc, arith::ConstantOp::create(rewriter, loc, *valueIt++),
            alloc, llvm::ArrayRef(indices));
        return;
      }

      for (uint64_t i = 0, e = valueShape[dimension]; i != e; ++i) {
        indices.push_back(constantIndices[i]);
        storeElements(dimension + 1);
        indices.pop_back();
      }
    };

    storeElements(/*dimension=*/0);

    rewriter.replaceOp(op, alloc);
    return success();
  }
};
```

</td><td>

```scheme
(define (%%store-const-elements! loc ctx const-attr shape alloc)
  (let* ([idx        (mlir::IndexType::get ctx)]
         [f64        (mlir::Float64Type::get ctx)]
         [max-dim    (apply max 0 shape)]
         [idx-consts (map (lambda (i)
                            (begin-mlir-code
                                c = arith.constant () (value : i :index) :loc loc -> idx))
                          (iota max-dim))])
    (define (store! dim elem-idx indices)
      (if (eqv? dim (length shape))
          (let* ([fa    (mlir::DenseElementsAttr::getValueAt<f64> const-attr elem-idx)]
                 [fattr (mlir::FloatAttr::get<f64> ctx (mlir::FloatAttr::getValueAsDouble fa))]
                 [map   (%%identity-map-attr (length indices))])
            (begin-mlir-code
                c = arith.constant () (value : fattr) :loc loc -> f64
                affine.store (c alloc ,@indices) (map : map) :loc loc)
            (+ elem-idx 1))
          (let loop ([i 0] [ei elem-idx])
            (if (eqv? i (list-ref shape dim))
                ei
                (loop (+ i 1)
                      (store! (+ dim 1) ei
                              (append indices (list (list-ref idx-consts i)))))))))
    (store! 0 0 '())))
```

```scheme
(define-conversion-pattern (%%constant-lower! op operands-ref rw tc)
  :if-match
    %out = toy.constant ()
  :then-let
    ([loc         (mlir::Operation::getLoc op)]
     [ctx         (mlir::Operation::getContext op)]
     [tensor-type (mlir::Value::getType %out)])
  :rewrite %out :with
    alloc = (%%insert-alloc-and-dealloc! rw loc (%%tensor->memref-type tensor-type)
                                         (mlir::Operation::getBlock op))
    (%%store-const-elements! loc ctx (mlir::Operation::getAttr op "value")
                             (mlir::RankedTensorType::getShape tensor-type) alloc)
    alloc)
```

</td></tr>
</table>

Both allocate the buffer, create the index constants, and walk the dimensions recursively, storing one `arith.constant`
for each element. The DSL splits the walk into a function, so the pattern itself is the match and the final value, the
`alloc`.

### `toy.transpose`

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L283-L300">C++, comments left out (<code>LowerToAffineLoops.cpp</code>, L283-L300)</a></th><th><a href="https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L205-L218">CREST DSL, comments left out (<code>lower-to-affine.sls</code>, L205-L218)</a></th></tr>
<tr><td>

```cpp
struct TransposeOpLowering : public OpConversionPattern<toy::TransposeOp> {
  using OpConversionPattern<toy::TransposeOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(toy::TransposeOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const final {
    auto loc = op->getLoc();
    lowerOpToLoops(op, rewriter, [&](OpBuilder &builder, ValueRange loopIvs) {
      Value input = adaptor.getInput();

      SmallVector<Value, 2> reverseIvs(llvm::reverse(loopIvs));
      return affine::AffineLoadOp::create(builder, loc, input, reverseIvs);
    });
    return success();
  }
};
```

</td><td>

```scheme
(define-conversion-pattern (%%transpose-lower! op operands-ref rw tc)
  :if-match
    %out = toy.transpose (%in)
  :then-let
    ([tensor-type (mlir::Value::getType %out)]
     [elem-type   (mlir::RankedTensorType::getElementType (mlir::Value::getType %out))]
     [loc         (mlir::Operation::getLoc op)])
  :rewrite %out :with
    (%%lower-op-to-loops!
     op rw tensor-type
     (lambda (ivs)
       (let ([map (%%identity-map-attr (length ivs))])
         (begin-mlir-code
             v = affine.load (%in ,@(reverse ivs)) (map : map) :loc loc -> elem-type)))))
```

</td></tr>
</table>

Both load with the loop indices reversed, which is all a transposition is.

### `toy.func`

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L213-L238">C++, comments left out (<code>LowerToAffineLoops.cpp</code>, L213-L238)</a></th><th><a href="https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L226-L240">CREST DSL, comments left out (<code>lower-to-affine.sls</code>, L226-L240)</a></th></tr>
<tr><td>

```cpp
struct FuncOpLowering : public OpConversionPattern<toy::FuncOp> {
  using OpConversionPattern<toy::FuncOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(toy::FuncOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const final {
    if (op.getName() != "main")
      return failure();

    if (op.getNumArguments() || op.getFunctionType().getNumResults()) {
      return rewriter.notifyMatchFailure(op, [](Diagnostic &diag) {
        diag << "expected 'main' to have 0 inputs and 0 results";
      });
    }

    auto func = mlir::func::FuncOp::create(rewriter, op.getLoc(), op.getName(),
                                           op.getFunctionType());
    rewriter.inlineRegionBefore(op.getRegion(), func.getBody(), func.end());
    rewriter.eraseOp(op);
    return success();
  }
};
```

</td><td>

```scheme
(define (%%empty-signature? function-type)
  (and (eqv? 0 (mlir::FunctionType::getNumInputs function-type))
       (eqv? 0 (mlir::FunctionType::getNumResults function-type))))
```

```scheme
(define-conversion-pattern (%%func-lower! op operands-ref rw tc)
  :if-match
    toy.func ()
      :where (and (string=? "main" (mlir::StringAttr::getValue (:attr "sym_name")))
                  (%%empty-signature? (mlir::TypeAttr::getValue (:attr "function_type"))))
  :rewrite op :with
    func.func ()
    (sym_name : (mlir::Operation::getAttr op "sym_name"))
    (function_type : (mlir::Operation::getAttr op "function_type"))
    (:move-region op)
  :loc (mlir::Operation::getLoc op))
```

</td></tr>
</table>

Only a `main` with no arguments and no results is lowered. C++ checks the name, then returns `failure()`, and says why the
second condition failed with `notifyMatchFailure`. The DSL has both conditions in `:where`, and when one does not hold the
conversion reports `failed to legalize operation 'toy.func'` (`lowering-main-arguments.mlir`). The body moves with
`inlineRegionBefore` and `eraseOp` in C++, and with `(:move-region op)` in the DSL.

### `toy.return`

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L262-L277">C++, comments left out (<code>LowerToAffineLoops.cpp</code>, L262-L277)</a></th><th><a href="https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L246-L251">CREST DSL, comments left out (<code>lower-to-affine.sls</code>, L246-L251)</a></th></tr>
<tr><td>

```cpp
struct ReturnOpLowering : public OpConversionPattern<toy::ReturnOp> {
  using OpConversionPattern<toy::ReturnOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(toy::ReturnOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const final {
    if (op.hasOperand())
      return failure();

    rewriter.replaceOpWithNewOp<func::ReturnOp>(op);
    return success();
  }
};
```

</td><td>

```scheme
(define-conversion-pattern (%%return-lower! op operands-ref rw tc)
  :if-match
    toy.return ()
      :where (eqv? 0 (mlir::Operation::getNumOperands op))
  :rewrite op :with
    func.return ())
```

</td></tr>
</table>

Only a `return` with no operand is lowered, and it becomes a `func.return`.

### `toy.print`

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/mlir/LowerToAffineLoops.cpp#L244-L256">C++, comments left out (<code>LowerToAffineLoops.cpp</code>, L244-L256)</a></th><th><a href="https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/lower-to-affine.sls#L258-L262">CREST DSL, comments left out (<code>lower-to-affine.sls</code>, L258-L262)</a></th></tr>
<tr><td>

```cpp
struct PrintOpLowering : public OpConversionPattern<toy::PrintOp> {
  using OpConversionPattern<toy::PrintOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(toy::PrintOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const final {
    rewriter.modifyOpInPlace(op,
                             [&] { op->setOperands(adaptor.getOperands()); });
    return success();
  }
};
```

</td><td>

```scheme
(define-conversion-pattern (%%print-lower! op operands-ref rw tc)
  :if-match
    toy.print (%in)
  :rewrite op :with
    toy.print (%in))
```

</td></tr>
</table>

C++ updates the operands of the op in place with the converted ones. The DSL writes the `toy.print` again, with the
converted operand `%in`.

### The pipeline

<table>
<tr><th><a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch5/toyc.cpp#L137-L166">C++, comments left out (<code>toyc.cpp</code>, L137-L166)</a></th><th><a href="https://github.com/wcy123/crest/blob/c75cc9c762d247a423aee0630b5e51518578121c/samples/toy/ch5/toyc.sls#L112-L128">CREST DSL, comments left out (<code>toyc.sls</code>, L112-L128)</a></th></tr>
<tr><td>

```cpp
bool isLoweringToAffine = emitAction >= Action::DumpMLIRAffine;

if (enableOpt || isLoweringToAffine) {
  pm.addPass(mlir::createInlinerPass());

  mlir::OpPassManager &optPM = pm.nest<mlir::toy::FuncOp>();
  optPM.addPass(mlir::toy::createShapeInferencePass());
  optPM.addPass(mlir::createCanonicalizerPass());
  optPM.addPass(mlir::createCSEPass());
}

if (isLoweringToAffine) {
  pm.addPass(mlir::toy::createLowerToAffinePass());

  mlir::OpPassManager &optPM = pm.nest<mlir::func::FuncOp>();
  optPM.addPass(mlir::createCanonicalizerPass());
  optPM.addPass(mlir::createCSEPass());

  if (enableOpt) {
    optPM.addPass(mlir::affine::createLoopFusionPass());
    optPM.addPass(mlir::affine::createAffineScalarReplacementPass());
  }
}
```

</td><td>

```scheme
(define (%%run-pipeline! module-op ctx opt? emit-affine?)
  (with-PassManager pm (ctx)
    (mlir::PassManager::addPass pm (mlir::createInlinerPass))
    (let ([func-pm (mlir::PassManager::nest pm "toy.func")])
      (mlir::OpPassManager::addPass func-pm (toy:shape-inference-pass))
      (mlir::OpPassManager::addPass func-pm (mlir::createCanonicalizerPass))
      (mlir::OpPassManager::addPass func-pm (mlir::createCSEPass)))
    (when emit-affine?
      (mlir::PassManager::addPass pm (toy:lower-to-affine-pass))
      (let ([func-pm (mlir::PassManager::nest pm "func.func")])
        (mlir::OpPassManager::addPass func-pm (mlir::createCanonicalizerPass))
        (mlir::OpPassManager::addPass func-pm (mlir::createCSEPass))
        (when opt?
          (mlir::OpPassManager::addPass func-pm (mlir::affine::createLoopFusionPass))
          (mlir::OpPassManager::addPass func-pm
                                        (mlir::affine::createAffineScalarReplacementPass)))))
    (%%run-passes! pm module-op)))
```

</td></tr>
</table>

The same sequence in both: the inliner, then shape inference, canonicalize and CSE on `toy.func`; then the lowering; then
canonicalize and CSE on `func.func`; and with `--opt`, loop fusion and affine scalar replacement.

### What this adds up to

- **A pattern is a match and a rewrite written as the IR.** `%sum = toy.add (%lhs %rhs)` is the op as MLIR prints it, and
  `affine.for`, `affine.load` and `arith.mulf` are written in `begin-mlir-code` in the form they print. In C++ each of
  them is a call, `AffineLoadOp::create(builder, loc, ...)`, with its operands as arguments.
- **The conversion is one declaration.** What is legal, what is illegal, what is legal only sometimes, and the patterns
  are keys of `apply-conversion`.
- **The code of the patterns is shared as functions.** Where C++ uses a template over the two ops, the DSL uses a function
  and a symbol.
- **The loop nest is explicit.** C++ delegates it to `buildAffineLoopNest`, which hides the bounds and the step. The DSL writes them, so the lowering reads as the IR it produces; it is a choice, and both are possible.
- **What C++ gives that the DSL does not here:** a pattern can say why it did not match, with `notifyMatchFailure`. The
  DSL puts the conditions in `:where` and the conversion reports `failed to legalize operation`.

## Related Documents

- [inlining.md](../ch4/inlining.md) — how `DialectInlinerInterface` works
- [../ch4/README.md](../ch4/README.md) — Ch4 inlining feature
