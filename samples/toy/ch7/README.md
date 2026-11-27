# Toy Ch7 — Structs

Ch7 adds user-defined structs to Toy: a `struct` declaration, struct-typed parameters and variables, struct literals, and
`.` to select a field. In the dialect a struct is a new type, `!toy.struct<...>`, and two new ops, `toy.struct_constant` and
`toy.struct_access`. MLIR folds them away before the lowering, so the lowering to Affine and to LLVM is the one of Ch6,
file for file. Like Ch2 to Ch6, Ch7 needs LLVM 23.

## The pipeline

`toyc` runs one pipeline of passes. **Ch7 adds step 2**: a canonicalize before shape inference. The other steps are Ch6's,
and every step after step 1 has a number one higher than in Ch6.

| Step | Pass | Runs on | What it leaves |
|---|---|---|---|
| 1 | MLIR's inliner | module | the calls inlined |
| **2** | **canonicalize** | `toy.func` | each `toy.struct_access` of a `toy.struct_constant` folded to a `toy.constant`, and the unused `toy.struct_constant` erased (the shape inference of step 3 folds them as well, see "Take one pass out") |
| 3 | shape inference | `toy.func` | every type ranked |
| 4 | canonicalize + CSE | `toy.func` | the Toy module that `--emit=mlir --opt` prints |
| 5 | partial lowering (`toy:lower-to-affine-pass`) | module | `affine`, `arith`, `memref` and `func` ops, and a `toy.print` on a `memref` |
| 6 | canonicalize + CSE | `func.func` | the index constants folded into the subscripts |
| 7 | loop fusion (`--opt` only) | `func.func` | one loop nest |
| 8 | affine scalar replacement (`--opt` only) | `func.func` | the temporary buffers removed |
| 9 | LLVM lowering (`toy:lower-to-llvm-pass`) | module | `llvm` ops only |
| 10 | DI scope (`mlir::LLVM::createDIScopeForLLVMFuncOpPass`) | module | a debug scope on each `llvm.func` |

Which steps run depends on the action:

| Action | Steps that run |
|---|---|
| `--emit=mlir` | none |
| `--emit=mlir --opt` | 1 to 4 |
| `--emit=mlir-affine` | 1 to 6 |
| `--emit=mlir-affine --opt` | 1 to 8 |
| `--emit=mlir-llvm`, `--emit=llvm`, `--emit=jit` | 1 to 6, 9 and 10 |
| the same three with `--opt` | 1 to 10 |

The code is `%%run-pipeline!` in [`toyc.sls` (L195-L215)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toyc.sls#L195-L215), and in C++ [`toyc.cpp` (L144-L199)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/toyc.cpp#L144-L199). "Take one pass out" below shows
what step 2 does, and what it does not do here.

## Try it

`example.toy` has a struct of two fields. `multiply_transpose` takes the struct and multiplies the transpose of the first
field by the transpose of the second, and `main` makes a struct and prints the result:

```text
struct Struct {
  var a;
  var b;
}

def multiply_transpose(Struct value) {
  return transpose(value.a) * transpose(value.b);
}

def main() {
  Struct value = {[[1, 2, 3], [4, 5, 6]], [[1, 2, 3], [4, 5, 6]]};
  var c = multiply_transpose(value);
  print(c);
}
```

Run the commands in this directory. `./toyc` finds `scheme-mlir` through `CREST_BUILD_DIR` or `PATH`, see the commands of
the [Ch3 README](../ch3/README.md#commands). `--emit=mlir-affine`, `--emit=mlir-llvm`, `--emit=llvm` and `--emit=jit` work as in
[Ch5](../ch5/README.md#try-it) and [Ch6](../ch6/README.md#try-it): once the structs are folded, the module has only tensor ops.

### `--emit=ast`

```sh
./toyc example.toy --emit=ast
```

```text
  Module:
    Struct: Struct @example.toy:0:1
      Variables: [
        VarDecl a<> @example.toy:1:3
        VarDecl b<> @example.toy:2:3
      ]
    Function
      Proto 'multiply_transpose' @example.toy:5:1
      Params: [value]
      Block {
        Return
          BinOp: * @example.toy:6:29
            Call 'transpose' [ @example.toy:6:10
              BinOp: . @example.toy:6:25
                var: value @example.toy:6:20
                var: a @example.toy:6:26
            ]
            Call 'transpose' [ @example.toy:6:31
              BinOp: . @example.toy:6:46
                var: value @example.toy:6:41
                var: b @example.toy:6:47
            ]
      } // Block
    Function
      Proto 'main' @example.toy:9:1
      Params: []
      Block {
        VarDecl value<Struct> @example.toy:10:10
          Struct Literal: @example.toy:10:18
            Literal: <2,3>[ <3>[ 1, 2, 3], <3>[ 4, 5, 6]] @example.toy:10:19
            Literal: <2,3>[ <3>[ 1, 2, 3], <3>[ 4, 5, 6]] @example.toy:10:43
        VarDecl c<> @example.toy:11:3
          Call 'multiply_transpose' [ @example.toy:11:11
            var: value @example.toy:11:30
          ]
        Print [ @example.toy:12:3
          var: c @example.toy:12:9
        ]
      } // Block
```

The new parts are the `Struct:` with its `Variables:` (the fields have no initial value), the `Struct Literal:` that holds
the two tensor literals, `VarDecl value<Struct>`, whose type is the name of the struct, and the `.` as a `BinOp`.

### `--emit=mlir`

```sh
./toyc example.toy --emit=mlir
```

```mlir
module {
  toy.func private @multiply_transpose(%arg0: !toy.struct<tensor<*xf64>, tensor<*xf64>>) -> tensor<*xf64> {
    %0 = toy.struct_access %arg0[1] : !toy.struct<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
    %1 = toy.transpose(%0 : tensor<*xf64>) to tensor<*xf64>
    %2 = toy.struct_access %arg0[0] : !toy.struct<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
    %3 = toy.transpose(%2 : tensor<*xf64>) to tensor<*xf64>
    %4 = toy.mul %3, %1 : tensor<*xf64>
    toy.return %4 : tensor<*xf64>
  }
  toy.func @main() {
    %0 = toy.struct_constant [dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>, dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>] : !toy.struct<tensor<*xf64>, tensor<*xf64>>
    %1 = toy.generic_call @multiply_transpose(%0) : (!toy.struct<tensor<*xf64>, tensor<*xf64>>) -> tensor<*xf64>
    toy.print %1 : tensor<*xf64>
    toy.return
  }
}
```

- The parameter of `multiply_transpose` has the struct type, `!toy.struct<tensor<*xf64>, tensor<*xf64>>`: one element type
  for each field, unranked, because a field is declared with `var` and has no shape.
- `value.a` and `value.b` are `toy.struct_access` with the index of the field: `%arg0[0]` for `a` and `%arg0[1]` for `b`.
- The struct literal is one `toy.struct_constant`. Its `value` is an array attribute with one tensor for each field, and the
  tensors keep their real shape (`tensor<2x3xf64>`) while the type of the struct says `tensor<*xf64>`.

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
    toy.print %2 : tensor<3x2xf64>
    toy.return
  }
}
```

No struct is left. The inliner put `multiply_transpose` into `main`, the `toy.struct_access` of the `toy.struct_constant`
were folded to a `toy.constant` for each field, and the `toy.struct_constant` that nothing uses was erased. The two fields
of this struct are the same tensor, so CSE made one constant and one `toy.transpose` of it.

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
@@ -1,16 +1,9 @@
 module {
-  toy.func private @multiply_transpose(%arg0: !toy.struct<tensor<*xf64>, tensor<*xf64>>) -> tensor<*xf64> {
-    %0 = toy.struct_access %arg0[1] : !toy.struct<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
-    %1 = toy.transpose(%0 : tensor<*xf64>) to tensor<*xf64>
-    %2 = toy.struct_access %arg0[0] : !toy.struct<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
-    %3 = toy.transpose(%2 : tensor<*xf64>) to tensor<*xf64>
-    %4 = toy.mul %3, %1 : tensor<*xf64>
-    toy.return %4 : tensor<*xf64>
-  }
   toy.func @main() {
-    %0 = toy.struct_constant [dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>, dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>] : !toy.struct<tensor<*xf64>, tensor<*xf64>>
-    %1 = toy.generic_call @multiply_transpose(%0) : (!toy.struct<tensor<*xf64>, tensor<*xf64>>) -> tensor<*xf64>
-    toy.print %1 : tensor<*xf64>
+    %0 = toy.constant dense<[[1.000000e+00, 2.000000e+00, 3.000000e+00], [4.000000e+00, 5.000000e+00, 6.000000e+00]]> : tensor<2x3xf64>
+    %1 = toy.transpose(%0 : tensor<2x3xf64>) to tensor<3x2xf64>
+    %2 = toy.mul %1, %1 : tensor<3x2xf64>
+    toy.print %2 : tensor<3x2xf64>
     toy.return
   }
 }
```

### `--emit=jit`

```sh
./toyc example.toy --emit=jit
```

```text
1.000000 16.000000
4.000000 25.000000
9.000000 36.000000
```

`--emit=jit --opt` prints the same.

### Take one pass out

Delete one line of `%%run-pipeline!` in `toyc.sls` and run `./toyc example.toy --emit=mlir --opt` again:

| Line removed | What you see |
|---|---|
| `(mlir::createInlinerPass)` | `Shape inference failed, 5 operations couldn't be inferred` for `multiply_transpose` and `2 operations` for `main`, and `toyc` exits with status 4: with no inlining the arguments of `multiply_transpose` stay unranked |
| the first `(mlir::createCanonicalizerPass)`, step 2 | the same output |
| `(toy:shape-inference-pass)` | the struct is still folded, but the types stay unranked: `toy.transpose(%0 : tensor<*xf64>) to tensor<*xf64>`, and the same for `toy.mul` and `toy.print` |
| the second `(mlir::createCanonicalizerPass)` | the same output |
| both `(mlir::createCanonicalizerPass)` | the same output |
| `(mlir::createCSEPass)` | two `toy.transpose` of the same constant, and a `toy.mul` of the two |

Step 2 does nothing here, and the second canonicalize does nothing alone. Shape inference is applied with MLIR's greedy
pattern driver, which also folds the ops it visits, so the `toy.struct_access` of a `toy.struct_constant` is folded there,
and the output is the same with any of the two canonicalizes, or both, removed. Step 2 is in the pipeline because the C++
pass needs it: the C++ shape inference infers an op only when all its operands are ranked tensors, a struct operand is not,
and a `toy.struct_access` that is left makes the pass fail with `Shape inference failed`. The folded `toy.constant` has the
unranked type of the field, so the shape inference of this chapter has one more pattern, for `toy.constant`
(`%%infer-constant`, the counterpart of the C++ `ConstantOp::inferShapes`), which gives the constant the type of its value.

### `fields.toy`: which field is which

The two fields of `example.toy` are the same tensor, so a swapped index would not show. `fields.toy` has two different
fields, and prints the second before the first:

```text
struct Pair {
  var first;
  var second;
}

def main() {
  Pair p = {[1, 2, 3], [[4, 5], [6, 7]]};
  var a = p.first;
  var b = p.second;
  print(b);
  print(a);
}
```

```sh
./toyc fields.toy --emit=mlir
```

```mlir
module {
  toy.func @main() {
    %0 = toy.struct_constant [dense<[1.000000e+00, 2.000000e+00, 3.000000e+00]> : tensor<3xf64>, dense<[[4.000000e+00, 5.000000e+00], [6.000000e+00, 7.000000e+00]]> : tensor<2x2xf64>] : !toy.struct<tensor<*xf64>, tensor<*xf64>>
    %1 = toy.struct_access %0[0] : !toy.struct<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
    %2 = toy.struct_access %0[1] : !toy.struct<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
    toy.print %2 : tensor<*xf64>
    toy.print %1 : tensor<*xf64>
    toy.return
  }
}
```

The index of `p.first` is 0 and of `p.second` is 1, the order of the declaration, and the `toy.struct_constant` has the
vector first and the 2x2 array second. With `--opt` each access folds to the constant of its field:

```sh
./toyc fields.toy --emit=mlir --opt
```

```mlir
module {
  toy.func @main() {
    %0 = toy.constant dense<[1.000000e+00, 2.000000e+00, 3.000000e+00]> : tensor<3xf64>
    %1 = toy.constant dense<[[4.000000e+00, 5.000000e+00], [6.000000e+00, 7.000000e+00]]> : tensor<2x2xf64>
    toy.print %1 : tensor<2x2xf64>
    toy.print %0 : tensor<3xf64>
    toy.return
  }
}
```

```sh
./toyc fields.toy --emit=jit
```

```text
4.000000 5.000000
6.000000 7.000000
1.000000 2.000000 3.000000
```

The 2x2 array is printed first, as two rows, then the vector, on one line with no newline at its end (the `toy.print` of
Ch6).

### One rule at a time

Each rule of this chapter has a test that fails without it. Switch off one rule in `toy.sls` and run the tests of the
chapter:

| Rule | Program | Tests that fail when it is switched off |
|---|---|---|
| fold of `toy.constant` | `fields.toy` | `action-mlir-opt-fields.mlir` and `action-jit-fields.mlir`, and no other |
| fold of `toy.struct_constant` | `example.toy`, `fields.toy`, `struct-order.toy` | the eight tests that fold a struct: `action-mlir-opt-example.mlir`, `action-mlir-opt-fields.mlir`, `action-mlir-affine-example.mlir`, `action-mlir-affine-opt-example.mlir`, `action-mlir-llvm-example.mlir`, `action-jit-example.mlir`, `action-jit-fields.mlir`, `action-jit-struct-order.mlir` |
| fold of `toy.struct_access` | `example.toy`, `fields.toy`, `struct-order.toy` | the same eight |
| `%%infer-constant` in `shape-inference.sls` | `example.toy`, `fields.toy`, `struct-order.toy` | the same eight |
| fold of `toy.cast` (the folder of Ch4) | `tensor-call.toy` | `action-mlir-opt-tensor-call.mlir`, and no other |
| the struct case of `:materialize-constant` | `materialize-struct-constant.mlir` | `materialize-struct-constant.mlir`, and no other |
| the verifier of the type `!toy.struct` | `verify-struct-type-element.mlir` | `verify-struct-type-element.mlir`, and no other |
| the printer of the type `!toy.struct` | every program with a struct | `action-mlir-example.mlir`, `action-mlir-fields.mlir`, `materialize-struct-constant.mlir` |
| the verifier of `toy.struct_access` | `verify-struct-access-range.mlir`, `verify-struct-access-type.mlir` | those two |
| step 2, the first canonicalize | no program | no test: the output does not change |

`tensor-call.toy` is a program with no struct, and it is here because `example.toy` passes only structs to its function: the
inliner puts a `toy.cast` where `square(a)` passes a tensor, shape inference gives the cast the type of its operand, and the
fold of `toy.cast` removes it. The Ch6 examples reach that fold as well, since they pass tensors. `materialize-struct-constant.mlir`
is written in MLIR, not in Toy, because no Toy program reaches the struct case: shape inference fails on any struct value that
is left, so `toyc` never has to make a folded struct again, and the test calls the hook of the dialect directly. The Toy
language also cannot write a struct inside a struct, because a field is declared with `var`.

### Known limitations and differences from C++

- **Two structs with the same layout.** The front end finds the declaration of a struct by the type of the value, and a
  struct type is the list of its element types, so the first declaration with that list wins. In `two-structs.toy` the
  structs `A` and `B` both have two fields, and `v.q` of a `B` is looked for in `A`:

  ```text
  struct A {
    var x;
    var y;
  }

  struct B {
    var p;
    var q;
  }

  def second(B v) {
    return v.q;
  }

  def main() {
    B v = {[1, 2], [3, 4]};
    var r = second(v);
    print(r);
  }
  ```

  ```sh
  ./toyc two-structs.toy --emit=mlir 2>&1
  ```

  ```text
  Exception in mlir-gen: field not found in struct with irritant "q"
  ```

  C++ does not have this limit: it keeps the name of the struct with the variable and looks the declaration up by that
  name (`getStructFor`, in the table "Which field is which" below).
- **A number that starts with a dot.** The lexer was written to read `.5` as a number when a digit follows the dot, and
  the `5` is lost:

  ```sh
  echo 'def main() { var a = [.5, 1.5]; print(a); }' | ./toyc - --emit=jit
  ```

  ```text
  0.000000 1.500000
  ```

  The array is `[#f, 1.5]`, and the first element prints as 0. In C++ Ch7 a number starts with a digit, so `.5` is not read as a number. [The number rule of the C++ lexer (`Lexer.h` L155-L164)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/include/toy/Lexer.h#L155-L164), [the dot and number rules of `lexer.sls` (`lexer.sls` L116-L135)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/lexer.sls#L116-L135).
- **A number in a struct literal.** C++ accepts a number as an element of a struct literal. Here an element is a `[...]`
  tensor literal or a `{...}` struct literal:

  ```sh
  printf 'struct P {\n  var a;\n  var b;\n}\n\ndef main() {\n  P p = {1, 2};\n  print(p.a);\n}\n' | ./toyc - --emit=ast 2>&1
  ```

  ```text
  Parse error (6, 10): expected '{ or [' in struct literal expression but got tok-number
  ```

## What you learn about MLIR here

Ch6 was about lowering. Ch7 is about the dialect itself: a type of its own, ops that fold, and the checks that go with them.

The links are permalinks: the Scheme files of this chapter at the commit `497d697d9eb5` of this repository, and the C++ files of
the LLVM Toy tutorial at the commit `392dfff97d29` of LLVM.

1. **A dialect can define its own types.** `!toy.struct<tensor<*xf64>, tensor<*xf64>>` has parameters, the element types, a
   verifier that accepts a tensor or another struct, and a text form with `<`, `,` and `>`. In C++ this is a class
   with a `TypeStorage` that holds, hashes and compares the parameters, and `parseType` and `printType` on the dialect. In the DSL the
   parameters, the verifier, the parser and the printer are the clauses of one `define-type`.
   - Scheme: [`define-type struct` (`toy.sls` L272-L294)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L272-L294)
   - C++: [`StructTypeStorage` (`Dialect.cpp` L509-L558)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/Dialect.cpp#L509-L558), [`parseType` and `printType` (`Dialect.cpp` L582-L632)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/Dialect.cpp#L582-L632)
2. **An op can fold, and folding is not a rewrite pattern.** `fold` returns what the op is equal to: an attribute, for a
   constant, or an existing value. The ops that are `constant-like` return their own `value`, and `toy.struct_access`
   returns the element of the constant struct that its operand has. MLIR's canonicalizer and greedy driver call the folders,
   so `toy.struct_access` of `toy.struct_constant` disappears with no pattern written for it.
   - Scheme: [`toy.constant` (`toy.sls` L340-L342)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L340-L342), [`toy.struct_constant` (`toy.sls` L478-L480)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L478-L480), [`toy.struct_access` (`toy.sls` L494-L501)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L494-L501)
   - C++: [the three `fold` functions (`ToyCombine.cpp` L30-L45)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/ToyCombine.cpp#L30-L45)
3. **`materializeConstant` makes an op of the dialect from the attribute that a fold returned.** A folded
   `toy.struct_access` gives an attribute and MLIR needs an op: the dialect makes a `toy.struct_constant` for a struct type
   and a `toy.constant` for a tensor.
   - Scheme: [`:materialize-constant` (`toy.sls` L295-L303)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L295-L303)
   - C++: [`materializeConstant` (`Dialect.cpp` L656-L665)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/Dialect.cpp#L656-L665)
4. **A verifier checks what the types cannot say.** The type of `toy.struct_access`'s result must be the element at the
   index, and the index must be in range. The type of the struct says neither.
   - Scheme: [`%%verify-struct-access` (`toy.sls` L205-L217)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L205-L217)
   - C++: [`StructAccessOp::verify` (`Dialect.cpp` L457-L468)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/Dialect.cpp#L457-L468)
5. **A pass that needs an interface fixes the order of the passes.** The C++ shape inference works on ops with
   ranked operands and the `ShapeInference` interface, and a struct has neither, so the structs must be folded before it:
   that is step 2. The DSL's shape inference is a set of patterns, so it does not fail on an op it has no pattern for.
   - Scheme: [`%%infer-constant` and the pattern set (`shape-inference.sls` L83-L101)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/shape-inference.sls#L83-L101)
   - C++: [the worklist and the failure (`ShapeInferencePass.cpp` L73-L99)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/ShapeInferencePass.cpp#L73-L99), [`allOperandsInferred` (`ShapeInferencePass.cpp` L104-L108)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/ShapeInferencePass.cpp#L104-L108)

## What's new over Ch6

| Feature | Ch6 | Ch7 |
|---|---|---|
| Language | `def`, `var`, calls, `print` | + `struct`, struct-typed parameters and variables, `{...}` literals, `a.b` |
| Lexer | — | the `struct` keyword, and `.` as a token |
| AST | functions only | + `struct-ast`, `struct-literal-expr`, `module-ast:structs` |
| Dialect | tensor ops | + the struct type, `toy.struct_constant`, `toy.struct_access` |
| Folders | `toy.cast` | + `toy.constant`, `toy.struct_constant`, `toy.struct_access` |
| Shape inference | `toy.add`, `toy.mul`, `toy.cast`, `toy.transpose` | + `toy.constant` |
| Pipeline | inline, shape inference, canonicalize | + a canonicalize before shape inference |
| Lowering | Affine, LLVM | unchanged: `lower-to-affine.sls` and `lower-to-llvm.sls` differ from Ch6's only in the library name |

### Dialect additions (`toy.sls`)

| Op / type | Meaning |
|---|---|
| `toy.struct_constant` | A constant struct. The attribute `value` is an `ArrayAttr` of `DenseElementsAttr` (or a nested `ArrayAttr` for a nested struct), and the result is a struct type. |
| `toy.struct_access` | `%s[N]`: the field `N` of a struct value. The attribute `index` is an `i64`. |
| `!toy.struct<T, ...>` | A dialect type made with `define-type`: its parameters are one `TypeAttr` for each element, `:verify` accepts a tensor or a struct as an element, and `:parse` and `:print` give the `struct<...>` syntax of the C++ `ToyDialect::parseType` and `printType`. `toy.struct?`, `toy.struct` and `toy.struct-params` are generated. |

The `:materialize-constant` hook of the dialect makes a `toy.struct_constant` for a struct type and a `toy.constant`
otherwise, so a fold can produce either.

### Front end

- **`lexer.sls`** — the new `tok-struct`. A `.` is returned as its own token, so `value.a` is not read as a number.
- **`parser.sls`** — `parseStruct ::= 'struct' identifier '{' var-decl+ '}'`. `parseModule` accepts structs and functions in
  any order, and a function may use a struct that is declared after it (`struct-order.toy`). `%%parse-struct-literal` parses the struct
  literals, and `Name ident = expr` declares a struct-typed variable.
- **`ast.sls`** — `struct-ast`, `struct-literal-expr` and `module-ast:structs`. `--emit=ast` dumps the struct declarations.
- **`mlir-gen.sls`** — a `struct-map` (name to type and declaration) goes through the generation. A struct literal becomes a
  `toy.struct_constant`, `a.b` becomes a `toy.struct_access` with the index of the field in the declaration, and a
  struct-typed parameter gets the struct type instead of an unranked tensor.

### Folders (`toy.sls`)

Ch7 gives three ops a `:fold` clause, as the C++ `ConstantOp::fold`, `StructConstantOp::fold` and `StructAccessOp::fold`
do. The fold of `toy.cast`, the one that `CastOpInterface` gives in C++, is older: it is in `toy.sls` since Ch4.

| Op | Folds to |
|---|---|
| `toy.constant`, `toy.struct_constant` | their own `value` (that is what makes them constants: they are also `constant-like`) |
| `toy.struct_access` | the element N of the constant `value` of its operand: `toy.struct_access(toy.struct_constant{[v0, v1, ...]}, N)` becomes `toy.constant{vN}`, which `materialize-constant` makes |
| `toy.cast` (Ch4) | its operand, when the operand already has the type of the result |

The ops are `pure`, so the greedy driver erases a `toy.struct_constant` that nothing uses. `mlir-gen` gives a struct literal
the unranked tensors, as C++ does, so a call passes the type of the parameter of the callee and the inliner needs no cast.

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect, with the struct type and ops | `define-dialect`, `define-type`, `define-op` | the type and `toy.struct_constant` and `toy.struct_access` are declared in it |
| The text form of `toy.struct_access` and `toy.struct_constant` | `:assembly-format` | `` $input `[` $index `]` attr-dict `:` type($input) `->` type($output) `` and `` $value attr-dict `:` type($output) ``, as in C++. The attribute `index` has a `:buildable-type :i64`, so the text is `[1]`, as ODS prints an `I64Attr` |
| The folders | the `:fold` clause of `define-op` | the clause returns `fold-attribute` or `fold-value` |
| The `:materialize-constant` hook | `begin-mlir-code` with `with-current-OpBuilder` | the hook returns the op, not its result |
| Every op that `mlir-gen.sls` creates, including the struct ops | `begin-mlir-code` | as in Ch2 |
| The result type of `toy.struct_access` | `:interfaces ((mlir::InferTypeOpInterface ...))` | as in Ch2: the C++ `StructAccessOp` builder takes the type of the element at the index, and so does the op here |
| The shape of a constant | `define-rewrite-pattern` (`%%infer-constant`) | as in Ch4 |
| Everything else | as in Ch3 to Ch6 | the canonicalization patterns, shape inference, inlining, the lowerings and their registration |

## Why the struct is written as it is

C++ writes the struct in several places: `Dialect.cpp` has the `StructTypeStorage`, `parseType`, `printType`, the verifiers
and `materializeConstant`; `Ops.td` declares the ops; `ToyCombine.cpp` has the folders; `Parser.h` and `MLIRGen.cpp` have
the front end. `toy.sls` has the type, the ops, the verifiers, the folders and the hook in one `define-dialect`, and the front
end is in `parser.sls` and `mlir-gen.sls`. Here they are, piece to piece. The titles of the tables are permalinks, with the
lines of the code: the C++ files at the commit of LLVM they were taken from (`392dfff97d29`), and the Scheme files at the commit
`497d697d9eb5` of this repository. A later change to the Scheme files does not move them.

### The struct type

<table>
<tr><th>C++, comments left out (<code>Dialect.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/Dialect.cpp#L509-L558">L509-L558</a>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/Dialect.cpp#L565-L579">L565-L579</a>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/Dialect.cpp#L582-L632">L582-L632</a>)</th><th>CREST DSL, comments left out (<code>toy.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L272-L294">L272-L294</a>)</th></tr>
<tr><td>

```cpp
struct StructTypeStorage : public mlir::TypeStorage {
  using KeyTy = llvm::ArrayRef<mlir::Type>;

  StructTypeStorage(llvm::ArrayRef<mlir::Type> elementTypes)
      : elementTypes(elementTypes) {}

  bool operator==(const KeyTy &key) const { return key == elementTypes; }

  static llvm::hash_code hashKey(const KeyTy &key) {
    return llvm::hash_value(key);
  }

  static KeyTy getKey(llvm::ArrayRef<mlir::Type> elementTypes) {
    return KeyTy(elementTypes);
  }

  static StructTypeStorage *construct(mlir::TypeStorageAllocator &allocator,
                                      const KeyTy &key) {
    llvm::ArrayRef<mlir::Type> elementTypes = allocator.copyInto(key);

    return new (allocator.allocate<StructTypeStorage>())
        StructTypeStorage(elementTypes);
  }

  llvm::ArrayRef<mlir::Type> elementTypes;
};
```

```cpp
StructType StructType::get(llvm::ArrayRef<mlir::Type> elementTypes) {
  assert(!elementTypes.empty() && "expected at least 1 element type");

  mlir::MLIRContext *ctx = elementTypes.front().getContext();
  return Base::get(ctx, elementTypes);
}

llvm::ArrayRef<mlir::Type> StructType::getElementTypes() {
  return getImpl()->elementTypes;
}
```

```cpp
mlir::Type ToyDialect::parseType(mlir::DialectAsmParser &parser) const {

  if (parser.parseKeyword("struct") || parser.parseLess())
    return Type();

  SmallVector<mlir::Type, 1> elementTypes;
  do {
    SMLoc typeLoc = parser.getCurrentLocation();
    mlir::Type elementType;
    if (parser.parseType(elementType))
      return nullptr;

    if (!llvm::isa<mlir::TensorType, StructType>(elementType)) {
      parser.emitError(typeLoc, "element type for a struct must either "
                                "be a TensorType or a StructType, got: ")
          << elementType;
      return Type();
    }
    elementTypes.push_back(elementType);

  } while (succeeded(parser.parseOptionalComma()));

  if (parser.parseGreater())
    return Type();
  return StructType::get(elementTypes);
}

void ToyDialect::printType(mlir::Type type,
                           mlir::DialectAsmPrinter &printer) const {
  StructType structType = llvm::cast<StructType>(type);

  printer << "struct<";
  llvm::interleaveComma(structType.getElementTypes(), printer);
  printer << '>';
}
```

</td><td>

```scheme
(define-type struct
  (:verify (params)
    (or (and (pair? params)
             (for-all (lambda (param)
                        (let ([element (mlir::TypeAttr::getValue param)])
                          (or (mlir::isa<TensorType>? element) (toy.struct? element))))
                      params))
        "element type for a struct must either be a TensorType or a StructType"))
  (:parse (parser)
    (and (mlir::OpAsmParser::parseLess parser)
         (let ([types (%%parse-type-list parser)])
           (and types
                (mlir::OpAsmParser::parseGreater parser)
                (map mlir::TypeAttr::get types)))))
  (:print (printer params)
    (mlir::OpAsmPrinter::printString printer "<")
    (let loop ([ts (map mlir::TypeAttr::getValue params)] [first #t])
      (unless (null? ts)
        (unless first (mlir::OpAsmPrinter::printString printer ", "))
        (mlir::OpAsmPrinter::printType printer (car ts))
        (loop (cdr ts) #f)))
    (mlir::OpAsmPrinter::printString printer ">")))
```

</td></tr>
</table>

C++ declares a storage class with the parameters, how to compare and hash them, and how to allocate them in the context,
then `StructType::get`, `parseType` and `printType`. The DSL writes the three things that the type needs, the
`:verify`, the `:parse` and the `:print`, and `define-type` makes the storage, the constructor and the predicates
(`toy.struct`, `toy.struct?`, `toy.struct-params`). C++ puts the check of the element types in `parseType`; the DSL puts it in the `:verify` clause, and
`verify-struct-type-element.mlir` checks the message. The C++ printer uses `interleaveComma`; the DSL prints the comma between the elements with a loop.

### The ops

<table>
<tr><th>C++, comments left out (<code>Ops.td</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/include/toy/Ops.td#L379-L402">L379-L402</a>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/include/toy/Ops.td#L408-L430">L408-L430</a>)</th><th>CREST DSL, comments left out (<code>toy.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L470-L480">L470-L480</a>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L482-L501">L482-L501</a>)</th></tr>
<tr><td>

```cpp
def StructAccessOp : Toy_Op<"struct_access", [Pure]> {
  let summary = "struct access";
  let description = [{
    Access the Nth element of a value returning a struct type.
  }];

  let arguments = (ins Toy_StructType:$input, I64Attr:$index);
  let results = (outs Toy_Type:$output);

  let assemblyFormat = [{
    $input `[` $index `]` attr-dict `:` type($input) `->` type($output)
  }];

  let builders = [
    OpBuilder<(ins "Value":$input, "size_t":$index)>
  ];

  let hasVerifier = 1;

  let hasFolder = 1;
}
```

```cpp
def StructConstantOp : Toy_Op<"struct_constant", [ConstantLike, Pure]> {
  let summary = "struct constant";
  let description = [{
    Constant operation turns a literal struct value into an SSA value. The data
    is attached to the operation as an attribute. The struct constant is encoded
    as an array of other constant values. For example:

    ```mlir
      %0 = toy.struct_constant [
        dense<[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]> : tensor<2x3xf64>
      ] : !toy.struct<tensor<*xf64>>
    ```
  }];

  let arguments = (ins ArrayAttr:$value);
  let results = (outs Toy_StructType:$output);

  let assemblyFormat = "$value attr-dict `:` type($output)";

  let hasVerifier = 1;
  let hasFolder = 1;
}
```

</td><td>

```scheme
(define-op struct_constant
  :summary    "struct constant value"
  :traits     (constant-like pure)
  :attributes ((value %%array-attr?))
  :results    ((output toy.struct?))
  :assembly-format "$value attr-dict `:` type($output)"
  (:verify (op) (%%verify-constant op))
  (:fold (op operand-attributes)
    (list (fold-attribute (mlir::Operation::getAttr op "value")))))
```

```scheme
(define-op struct_access
  :summary    "struct field access"
  :traits     (pure)
  :operands   ((input %%struct-type-value?))
  :attributes ((index %%integer-attr? :buildable-type :i64))
  :results    ((output %%toy-type?))
  :interfaces ((mlir::InferTypeOpInterface
                (inferReturnTypes (context location operands attributes)
                                  (%%struct-access-result-types operands attributes))))
  :assembly-format "$input `[` $index `]` attr-dict `:` type($input) `->` type($output)"
  (:verify (op) (%%verify-struct-access op))
  (:fold (op operand-attributes)
    (let ([in (car operand-attributes)])
      (and in
           (list (fold-attribute
                  (mlir::ArrayAttr::getElement
                   in (mlir::IntegerAttr::getValue
                       (mlir::Operation::getAttr op "index")))))))))
```

</td></tr>
</table>

Both say the same: the traits (`constant-like` and `pure` for the constant, `pure` for the access), the operand and the
result, and the text form. C++ is TableGen, which makes the class, the builders, the accessors and the parser and printer,
and says `hasVerifier` and `hasFolder` and writes the two functions in C++ files. The DSL has the clause with the code in
it, and the type of the result of `toy.struct_access` comes from the `InferTypeOpInterface` where C++ has a builder that takes
the index.

### The verifier of `toy.struct_access`

<table>
<tr><th>C++, comments left out (<code>Dialect.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/Dialect.cpp#L457-L468">L457-L468</a>)</th><th>CREST DSL, comments left out (<code>toy.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L205-L217">L205-L217</a>)</th></tr>
<tr><td>

```cpp
llvm::LogicalResult StructAccessOp::verify() {
  StructType structTy = llvm::cast<StructType>(getInput().getType());
  size_t indexValue = getIndex();
  if (indexValue >= structTy.getNumElementTypes())
    return emitOpError()
           << "index should be within the range of the input struct type";
  mlir::Type resultType = getResult().getType();
  if (resultType != structTy.getElementTypes()[indexValue])
    return emitOpError() << "must have the same result type as the struct "
                            "element referred to by the index";
  return mlir::success();
}
```

</td><td>

```scheme
(define (%%verify-struct-access op)
  (let* ([struct-type (mlir::Value::getType (mlir::Operation::getOperand op 0))]
         [index       (mlir::IntegerAttr::getValue (mlir::Operation::getAttr op "index"))]
         [elements    (%%struct-element-types struct-type)])
    (cond
     [(>= index (length elements))
      (%%error op "index should be within the range of the input struct type")]
     [(not (equal? (mlir::Value::getType (mlir::Operation::getResult op 0))
                   (list-ref elements index)))
      (%%error op "must have the same result type as the struct element referred to by "
               "the index")]
     [else #t])))
```

</td></tr>
</table>

The same two checks, in the same order, with the same messages. C++ casts the type of the operand with `llvm::cast`;
the DSL gets the element types with `%%struct-element-types`.

### The folders

<table>
<tr><th>C++, comments left out (<code>ToyCombine.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/ToyCombine.cpp#L30-L45">L30-L45</a>)</th><th>CREST DSL, comments left out (<code>toy.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L340-L342">L340-L342</a>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L478-L480">L478-L480</a>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L494-L501">L494-L501</a>)</th></tr>
<tr><td>

```cpp
OpFoldResult ConstantOp::fold(FoldAdaptor adaptor) { return getValue(); }

OpFoldResult StructConstantOp::fold(FoldAdaptor adaptor) { return getValue(); }

OpFoldResult StructAccessOp::fold(FoldAdaptor adaptor) {
  auto structAttr =
      llvm::dyn_cast_if_present<mlir::ArrayAttr>(adaptor.getInput());
  if (!structAttr)
    return nullptr;

  size_t elementIndex = getIndex();
  return structAttr[elementIndex];
}
```

</td><td>

```scheme
(:fold (op operand-attributes)
  (list (fold-attribute (mlir::Operation::getAttr op "value"))))
```

```scheme
(:fold (op operand-attributes)
  (list (fold-attribute (mlir::Operation::getAttr op "value")))))
```

```scheme
(:fold (op operand-attributes)
  (let ([in (car operand-attributes)])
    (and in
         (list (fold-attribute
                (mlir::ArrayAttr::getElement
                 in (mlir::IntegerAttr::getValue
                     (mlir::Operation::getAttr op "index")))))))))
```

</td></tr>
</table>

C++ has three functions that return an `OpFoldResult`, the constant or `nullptr`. The DSL has a `:fold` clause for each,
which returns a list of folds, `fold-attribute` for an attribute and `fold-value` for a value, or `#f` for no fold. The
access folds only when `operand-attributes` has the constant of its operand.

### `materializeConstant`

<table>
<tr><th>C++, comments left out (<code>Dialect.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/Dialect.cpp#L656-L665">L656-L665</a>)</th><th>CREST DSL, comments left out (<code>toy.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toy.sls#L295-L303">L295-L303</a>)</th></tr>
<tr><td>

```cpp
mlir::Operation *ToyDialect::materializeConstant(mlir::OpBuilder &builder,
                                                 mlir::Attribute value,
                                                 mlir::Type type,
                                                 mlir::Location loc) {
  if (llvm::isa<StructType>(type))
    return StructConstantOp::create(builder, loc, type,
                                    llvm::cast<mlir::ArrayAttr>(value));
  return ConstantOp::create(builder, loc, type,
                            llvm::cast<mlir::DenseElementsAttr>(value));
}
```

</td><td>

```scheme
(:materialize-constant (builder value type loc)
  (with-current-OpBuilder builder
    (mlir::Value::getDefiningOp
     (if (toy.struct? type)
         (begin-mlir-code
             r = toy.struct_constant () (value : value) :loc loc -> type)
         (begin-mlir-code
             r = toy.constant () (value : value) :loc loc -> type)))))
```

</td></tr>
</table>

The same choice by type. C++ casts the attribute to the one that the op needs, and the DSL passes it as it is.
`materialize-struct-constant.mlir` runs the hook and checks that the op it makes is a `toy.struct_constant`.

### The parser

<table>
<tr><th>C++, comments left out (<code>Parser.h</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/include/toy/Parser.h#L174-L213">L174-L213</a>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/include/toy/Parser.h#L613-L643">L613-L643</a>)</th><th>CREST DSL, comments left out (<code>parser.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/parser.sls#L139-L159">L139-L159</a>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/parser.sls#L473-L491">L473-L491</a>)</th></tr>
<tr><td>

```cpp
std::unique_ptr<ExprAST> parseStructLiteralExpr() {
  auto loc = lexer.getLastLocation();
  lexer.consume(Token('{'));

  std::vector<std::unique_ptr<ExprAST>> values;
  do {
    if (lexer.getCurToken() == '[') {
      values.push_back(parseTensorLiteralExpr());
      if (!values.back())
        return nullptr;
    } else if (lexer.getCurToken() == tok_number) {
      values.push_back(parseNumberExpr());
      if (!values.back())
        return nullptr;
    } else {
      if (lexer.getCurToken() != '{')
        return parseError<ExprAST>("{, [, or number",
                                   "in struct literal expression");
      values.push_back(parseStructLiteralExpr());
    }

    if (lexer.getCurToken() == '}')
      break;

    if (lexer.getCurToken() != ',')
      return parseError<ExprAST>("} or ,", "in struct literal expression");

    lexer.getNextToken(); // eat ,
  } while (true);
  if (values.empty())
    return parseError<ExprAST>("<something>",
                               "to fill struct literal expression");
  lexer.getNextToken(); // eat }

  return std::make_unique<StructLiteralExprAST>(std::move(loc),
                                                std::move(values));
```

```cpp
std::unique_ptr<StructAST> parseStruct() {
  auto loc = lexer.getLastLocation();
  lexer.consume(tok_struct);
  if (lexer.getCurToken() != tok_identifier)
    return parseError<StructAST>("name", "in struct definition");
  std::string name(lexer.getId());
  lexer.consume(tok_identifier);

  if (lexer.getCurToken() != '{')
    return parseError<StructAST>("{", "in struct definition");
  lexer.consume(Token('{'));

  std::vector<std::unique_ptr<VarDeclExprAST>> decls;
  do {
    auto decl = parseDeclaration(/*requiresInitializer=*/false);
    if (!decl)
      return nullptr;
    decls.push_back(std::move(decl));

    if (lexer.getCurToken() != ';')
      return parseError<StructAST>(";",
                                   "after variable in struct definition");
    lexer.consume(Token(';'));
  } while (lexer.getCurToken() != '}');

  lexer.consume(Token('}'));
  return std::make_unique<StructAST>(loc, name, std::move(decls));
}
```

</td><td>

```scheme
(define (%%parse-struct-literal lex)
  (let ([loc (lexer:last-loc lex)])
    (lexer:consume! lex #\{)
    (let loop ([values '()])
      (let ([elem (if (equal? (lexer:cur-tok lex) #\{)
                      (%%parse-struct-literal lex)
                      (if (equal? (lexer:cur-tok lex) #\[)
                          (%%parse-tensor-literal lex)
                          (%%parse-error lex "{ or [" "in struct literal expression")))])
        (if (not elem)
            #f
            (let ([values (append values (list elem))])
              (cond
               [(equal? (lexer:cur-tok lex) #\})
                (lexer:get-next-token! lex)
                (make-struct-literal-expr loc values)]
               [(equal? (lexer:cur-tok lex) #\,)
                (lexer:get-next-token! lex)
                (loop values)]
               [else
                (%%parse-error lex "} or ," "in struct literal expression")])))))))
```

```scheme
(define (%%parse-struct lex)
  (let ([loc (lexer:last-loc lex)])
    (lexer:consume! lex tok-struct)
    (unless (equal? (lexer:cur-tok lex) tok-identifier)
      (%%parse-error lex "identifier" "after 'struct'"))
    (let ([name (lexer:id lex)])
      (lexer:consume! lex tok-identifier)
      (unless (equal? (lexer:cur-tok lex) #\{)
        (%%parse-error lex "{" "in struct definition"))
      (lexer:consume! lex #\{)
      (let loop ([vars '()])
        (cond
         [(equal? (lexer:cur-tok lex) #\})
          (lexer:consume! lex #\})
          (make-struct-ast loc name vars)]
         [(equal? (lexer:cur-tok lex) tok-var)
          (let ([v (%%parse-var-decl lex)])
            (if (not v) #f (loop (append vars (list v)))))]
         [else (%%parse-error lex "var or }" "in struct definition")])))))
```

</td></tr>
</table>

Both read `{` and elements and `}` for a literal, and `struct`, the name, `{`, the variables and `}` for a declaration.
C++ accepts a number as an element of a struct literal and requires a `;` after each variable of a struct. The DSL accepts
only `[...]` and `{...}` in a literal, and the `;` after a variable of a struct is optional.

### Which field is which

<table>
<tr><th>C++, comments left out (<code>MLIRGen.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/MLIRGen.cpp#L248-L310">L248-L310</a>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/MLIRGen.cpp#L312-L337">L312-L337</a>)</th><th>CREST DSL, comments left out (<code>mlir-gen.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/mlir-gen.sls#L143-L165">L143-L165</a>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/mlir-gen.sls#L175-L193">L175-L193</a>)</th></tr>
<tr><td>

```cpp
StructAST *getStructFor(ExprAST *expr) {
  llvm::StringRef structName;
  if (auto *decl = llvm::dyn_cast<VariableExprAST>(expr)) {
    auto varIt = symbolTable.lookup(decl->getName());
    if (!varIt.first)
      return nullptr;
    structName = varIt.second->getType().name;
  } else if (auto *access = llvm::dyn_cast<BinaryExprAST>(expr)) {
    if (access->getOp() != '.')
      return nullptr;
    auto *name = llvm::dyn_cast<VariableExprAST>(access->getRHS());
    if (!name)
      return nullptr;
    StructAST *parentStruct = getStructFor(access->getLHS());
    if (!parentStruct)
      return nullptr;

    VarDeclExprAST *decl = nullptr;
    for (auto &var : parentStruct->getVariables()) {
      if (var->getName() == name->getName()) {
        decl = var.get();
        break;
      }
    }
    if (!decl)
      return nullptr;
    structName = decl->getType().name;
  }
  if (structName.empty())
    return nullptr;

  auto structIt = structMap.find(structName);
  if (structIt == structMap.end())
    return nullptr;
  return structIt->second.second;
}

std::optional<size_t> getMemberIndex(BinaryExprAST &accessOp) {
  assert(accessOp.getOp() == '.' && "expected access operation");

  StructAST *structAST = getStructFor(accessOp.getLHS());
  if (!structAST)
    return std::nullopt;

  VariableExprAST *name = llvm::dyn_cast<VariableExprAST>(accessOp.getRHS());
  if (!name)
    return std::nullopt;

  auto structVars = structAST->getVariables();
  const auto *it = llvm::find_if(structVars, [&](auto &var) {
    return var->getName() == name->getName();
  });
  if (it == structVars.end())
    return std::nullopt;
  return it - structVars.begin();
}
```

```cpp
mlir::Value mlirGen(BinaryExprAST &binop) {
  mlir::Value lhs = mlirGen(*binop.getLHS());
  if (!lhs)
    return nullptr;
  auto location = loc(binop.loc());

  if (binop.getOp() == '.') {
    std::optional<size_t> accessIndex = getMemberIndex(binop);
    if (!accessIndex) {
      emitError(location, "invalid access into struct expression");
      return nullptr;
    }
    return StructAccessOp::create(builder, location, lhs, *accessIndex);
  }
```

</td><td>

```scheme
(define (%%mlir-gen-binary symtab struct-map expr)
  (let ([loc (%%loc (binary-expr:loc expr))]
        [op  (binary-expr:op expr)])
    (if (char=? op #\.)
        (let* ([lhs (%%mlir-gen-expr symtab struct-map (binary-expr:lhs expr))]
               [rhs (binary-expr:rhs expr)]
               [field-name (if (var-expr? rhs) (var-expr:name rhs)
                               (%%fail loc "invalid access into struct expression"))]
               [lhs-type   (mlir::Value::getType lhs)]
               [elem-types (if (toy.struct? lhs-type)
                               (%%struct-element-types lhs-type)
                               (%%fail loc "invalid access into struct expression"))]
               [struct-decl (%%find-struct-decl-by-type struct-map lhs-type)]
               [field-idx   (if struct-decl
                                (%%find-field-index struct-decl field-name)
                                (error 'mlir-gen "cannot find struct for field access" field-name))])
          (begin-mlir-code
              r = toy.struct_access (lhs)
              (index : field-idx :i64)
              :loc loc))
```

```scheme
(define (%%find-struct-decl-by-type struct-map stype)
  (call-with-current-continuation
   (lambda (return)
     (let ([keys (hashtable-keys   struct-map)]
           [vals (hashtable-values struct-map)])
       (vector-for-each (lambda (name pair)
                          (when (equal? (car pair) stype)
                            (return (cdr pair))))
                        keys vals))
     #f)))

(define (%%find-field-index struct-decl field-name)
  (let loop ([vars (struct-ast:variables struct-decl)] [i 0])
    (if (null? vars)
        (error 'mlir-gen "field not found in struct" field-name)
        (if (string=? (var-decl-expr:name (car vars)) field-name)
            i
            (loop (cdr vars) (+ i 1))))))
```

</td></tr>
</table>

C++ finds the declaration of the struct from the name that the variable was declared with (`getStructFor`), and follows
`a.b.c` through the declarations of the fields. The DSL finds it by the type of the value that the left side gives
(`%%find-struct-decl-by-type`), which is why two structs with the same layout cannot be told apart (see above).

### The struct literal

<table>
<tr><th>C++, comments left out (<code>MLIRGen.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/MLIRGen.cpp#L436-L457">L436-L457</a>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/mlir/MLIRGen.cpp#L472-L481">L472-L481</a>)</th><th>CREST DSL, comments left out (<code>mlir-gen.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/mlir-gen.sls#L111-L141">L111-L141</a>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/mlir-gen.sls#L226-L232">L226-L232</a>)</th></tr>
<tr><td>

```cpp
getConstantAttr(StructLiteralExprAST &lit) {
  std::vector<mlir::Attribute> attrElements;
  std::vector<mlir::Type> typeElements;

  for (auto &var : lit.getValues()) {
    if (auto *number = llvm::dyn_cast<NumberExprAST>(var.get())) {
      attrElements.push_back(getConstantAttr(*number));
      typeElements.push_back(getType(/*shape=*/{}));
    } else if (auto *lit = llvm::dyn_cast<LiteralExprAST>(var.get())) {
      attrElements.push_back(getConstantAttr(*lit));
      typeElements.push_back(getType(/*shape=*/{}));
    } else {
      auto *structLit = llvm::cast<StructLiteralExprAST>(var.get());
      auto attrTypePair = getConstantAttr(*structLit);
      attrElements.push_back(attrTypePair.first);
      typeElements.push_back(attrTypePair.second);
    }
  }
  mlir::ArrayAttr dataAttr = builder.getArrayAttr(attrElements);
  mlir::Type dataType = StructType::get(typeElements);
  return std::make_pair(dataAttr, dataType);
}
```

```cpp
mlir::Value mlirGen(StructLiteralExprAST &lit) {
  mlir::ArrayAttr dataAttr;
  mlir::Type dataType;
  std::tie(dataAttr, dataType) = getConstantAttr(lit);

  return StructConstantOp::create(builder, loc(lit.loc()), dataType,
                                  dataAttr);
}
```

</td><td>

```scheme
(define (%%mlir-gen-struct-attr struct-map expr)
  (let loop ([values (struct-literal-expr:values expr)]
             [attrs '()]
             [types '()])
    (if (null? values)
        (let* ([arr  (mlir::ArrayAttr::get (current-MLIRContext) attrs)]
               [stype (%%make-struct-type types)])
          (cons arr stype))
        (let ([v (car values)])
          (cond
           [(literal-expr? v)
            (let* ([dims  (literal-expr:dims v)]
                   [data  (%%collect-data v)]
                   [type  (mlir::RankedTensorType::get dims (mlir::Float64Type::get))]
                   [attr  (mlir::DenseElementsAttr::get<f64> type data)])
              (loop (cdr values)
                    (append attrs (list attr))
                    (append types (list (%%f64-unranked-tensor)))))]
           [(struct-literal-expr? v)
            (let* ([pair  (%%mlir-gen-struct-attr struct-map v)]
                   [attr  (car pair)]
                   [stype (cdr pair)])
              (loop (cdr values)
                    (append attrs (list attr))
                    (append types (list stype))))]
           [else
            (error '%%mlir-gen-struct-attr "unexpected struct field value" v)])))))
```

```scheme
(define (%%mlir-gen-struct-literal struct-map expr)
  (let* ([loc  (%%loc (struct-literal-expr:loc expr))]
         [pair (%%mlir-gen-struct-attr struct-map expr)]
         [arr  (car pair)]
         [stype (cdr pair)])
    (begin-mlir-code
        r = toy.struct_constant () (value : arr) :loc loc -> stype)))
```

</td></tr>
</table>

Both make an array attribute with the tensors and a struct type with the element types, and the same for a nested literal.
The element types are unranked, as C++ does, and the attribute has the real shape.

### The pipeline

<table>
<tr><th>C++, comments left out (<code>toyc.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch7/toyc.cpp#L144-L199">L144-L199</a>)</th><th>CREST DSL, comments left out (<code>toyc.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toyc.sls#L195-L215">L195-L215</a>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch7/toyc.sls#L217-L220">L217-L220</a>)</th></tr>
<tr><td>

```cpp
static int loadAndProcessMLIR(mlir::MLIRContext &context,
                              mlir::OwningOpRef<mlir::ModuleOp> &module) {
  if (int error = loadMLIR(context, module))
    return error;

  mlir::PassManager pm(module.get()->getName());
  if (mlir::failed(mlir::applyPassManagerCLOptions(pm)))
    return 4;

  bool isLoweringToAffine = emitAction >= Action::DumpMLIRAffine;
  bool isLoweringToLLVM = emitAction >= Action::DumpMLIRLLVM;

  if (enableOpt || isLoweringToAffine) {
    pm.addPass(mlir::createInlinerPass());

    mlir::OpPassManager &optPM = pm.nest<mlir::toy::FuncOp>();
    optPM.addPass(mlir::createCanonicalizerPass());
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

  if (isLoweringToLLVM) {
    pm.addPass(mlir::toy::createLowerToLLVMPass());
    pm.addPass(mlir::LLVM::createDIScopeForLLVMFuncOpPass());
  }

  if (mlir::failed(pm.run(*module)))
    return 4;
  return 0;
}
```

</td><td>

```scheme
(define (%%run-pipeline! module-op ctx opt? emit-affine? emit-llvm?)
  (with-PassManager pm (ctx)
    (mlir::PassManager::addPass pm (mlir::createInlinerPass))
    (let ([func-pm (mlir::PassManager::nest pm "toy.func")])
      (mlir::OpPassManager::addPass func-pm (mlir::createCanonicalizerPass))
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
    (when emit-llvm?
      (mlir::PassManager::addPass pm (toy:lower-to-llvm-pass))
      (mlir::PassManager::addPass pm (mlir::LLVM::createDIScopeForLLVMFuncOpPass)))
    (%%run-passes! pm module-op)))
```

```scheme
(define (%%run-passes! pm module-op)
  (unless (mlir::PassManager::run! pm module-op)
    (display "Optimization pipeline failed\n" (current-error-port))
    (%%quit 4)))
```

</td></tr>
</table>

The same sequence in both, with the canonicalize before shape inference that C++ added in this chapter.

### What this adds up to

- **A type, its ops and their rules are in one place.** The type, the ops, the verifiers, the folders and the hook of the
  dialect are in `toy.sls`, with the code of each rule next to the op that it belongs to. In C++ the ODS declares them and
  the rules are in three other files.
- **The DSL has less to write for the type.** There is no storage class, and the parser and the printer are clauses.
- **A fold is the whole of the struct's optimization.** No rewrite pattern is written for the structs: the folders and the
  canonicalizer remove them.
- **What C++ gives that the DSL does not here:** the declaration is found by the name of the variable's struct, so structs with the
  same layout work, and a struct literal may hold numbers.

## Related Documents

- [../ch6/README.md](../ch6/README.md) — Ch6 LLVM lowering and `toy.print` → `printf`
- [../ch3/README.md](../ch3/README.md) — Ch3 canonicalization patterns
- [../ch4/inlining.md](../ch4/inlining.md) — how inlining works
