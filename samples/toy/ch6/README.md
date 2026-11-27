# Toy Ch6 — Lowering to LLVM

Ch6 finishes the lowering that Ch5 began. What Ch5 left, `affine`, `arith`, `memref` and `func` ops and a `toy.print`,
is converted to the LLVM dialect. The module can then be printed as LLVM-dialect MLIR, translated to LLVM IR, or run in
the process with MLIR's `ExecutionEngine`. Like Ch2 to Ch5, Ch6 needs LLVM 23.

## The pipeline

`toyc` runs one pipeline of passes. Steps 1 to 3 are Ch4's and steps 4 to 7 are Ch5's. **Steps 8 and 9 are new in Ch6.**

| Step | Pass | Runs on | What it leaves |
|---|---|---|---|
| 1 | MLIR's inliner | module | the calls inlined (Ch4) |
| 2 | shape inference | `toy.func` | every type ranked (Ch4) |
| 3 | canonicalize + CSE | `toy.func` | the Toy module that `--emit=mlir --opt` prints (Ch4) |
| 4 | partial lowering (`toy:lower-to-affine-pass`) | module | `affine`, `arith`, `memref` and `func` ops, and a `toy.print` on a `memref` (Ch5) |
| 5 | canonicalize + CSE | `func.func` | the index constants folded into the subscripts (Ch5) |
| 6 | loop fusion (`--opt` only) | `func.func` | one loop nest (Ch5) |
| 7 | affine scalar replacement (`--opt` only) | `func.func` | the temporary buffers removed (Ch5) |
| **8** | **LLVM lowering** (`toy:lower-to-llvm-pass`) | module | `llvm` ops only, and the `builtin.module` |
| **9** | **DI scope** (`mlir::LLVM::createDIScopeForLLVMFuncOpPass`) | module | a debug scope on each `llvm.func` |

Which steps run depends on the action:

| Action | Steps that run |
|---|---|
| `--emit=mlir` | none |
| `--emit=mlir --opt` | 1 to 3 |
| `--emit=mlir-affine` | 1 to 5 |
| `--emit=mlir-affine --opt` | 1 to 7 |
| `--emit=mlir-llvm`, `--emit=llvm`, `--emit=jit` | 1 to 5, 8 and 9 |
| the same three with `--opt` | 1 to 9 |

The three new actions end differently:

| Action | After step 9 |
|---|---|
| `--emit=mlir-llvm` | prints the module in the LLVM dialect |
| `--emit=llvm` | translates the module to LLVM IR (`mlir::translateModuleToLLVMIR`) and prints the text; with `--opt`, LLVM's own O3 pipeline (`makeOptimizingTransformer`) runs on the LLVM IR first |
| `--emit=jit` | makes an `ExecutionEngine` from the module and calls `@main`; with `--opt` the engine runs the same O3 pipeline |

The code is `%%run-pipeline!` in [`toyc.sls` (L194-L213)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/toyc.sls#L194-L213), and in C++ [`toyc.cpp` (L144-L198)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/toyc.cpp#L144-L198). "Take one pass out" below
shows what the new steps do by removing them.

## Try it

`example.toy` is the program of Ch5: `multiply_transpose` is called four times by `main`, which prints `e`.

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
[Ch1](../ch1/README.md#try-it) and [Ch4](../ch4/README.md#try-it), and `--emit=mlir-affine` as in
[Ch5](../ch5/README.md#try-it). The module that `--emit=mlir-affine --opt` prints is the one that the LLVM lowering starts
from.

### From Affine to LLVM: `print.toy`

The module of `example.toy` in the LLVM dialect is long, so here is a small program that has every piece. `print.toy`
makes a vector of two numbers and prints it:

```text
def main() {
  var a = [1, 2];
  print(a);
}
```

Ch5 lowers it to this:

```sh
./toyc print.toy --emit=mlir-affine
```

```mlir
module {
  func.func @main() {
    %cst = arith.constant 2.000000e+00 : f64
    %cst_0 = arith.constant 1.000000e+00 : f64
    %alloc = memref.alloc() : memref<2xf64>
    affine.store %cst_0, %alloc[0] : memref<2xf64>
    affine.store %cst, %alloc[1] : memref<2xf64>
    toy.print %alloc : memref<2xf64>
    memref.dealloc %alloc : memref<2xf64>
    return
  }
}
```

Ch6 lowers that to this:

```sh
./toyc print.toy --emit=mlir-llvm
```

```mlir
module {
  llvm.func @free(!llvm.ptr)
  llvm.mlir.global internal constant @nl("\0A\00") {addr_space = 0 : i32}
  llvm.mlir.global internal constant @frmt_spec("%f \00") {addr_space = 0 : i32}
  llvm.func @printf(!llvm.ptr, ...) -> i32
  llvm.func @malloc(i64) -> !llvm.ptr
  llvm.func @main() {
    %0 = llvm.mlir.constant(2.000000e+00 : f64) : f64
    %1 = llvm.mlir.constant(1.000000e+00 : f64) : f64
    %2 = llvm.mlir.constant(2 : index) : i64
    %3 = llvm.mlir.constant(1 : index) : i64
    %4 = llvm.mlir.zero : !llvm.ptr
    %5 = llvm.getelementptr %4[%2] : (!llvm.ptr, i64) -> !llvm.ptr, f64
    %6 = llvm.ptrtoint %5 : !llvm.ptr to i64
    %7 = llvm.call @malloc(%6) : (i64) -> !llvm.ptr
    %8 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %9 = llvm.insertvalue %7, %8[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %10 = llvm.insertvalue %7, %9[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %11 = llvm.mlir.constant(0 : index) : i64
    %12 = llvm.insertvalue %11, %10[2] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %13 = llvm.insertvalue %2, %12[3, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %14 = llvm.insertvalue %3, %13[4, 0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %15 = llvm.mlir.constant(0 : index) : i64
    %16 = llvm.extractvalue %14[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %17 = llvm.getelementptr inbounds|nuw %16[%15] : (!llvm.ptr, i64) -> !llvm.ptr, f64
    llvm.store %1, %17 : f64, !llvm.ptr
    %18 = llvm.mlir.constant(1 : index) : i64
    %19 = llvm.extractvalue %14[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %20 = llvm.getelementptr inbounds|nuw %19[%18] : (!llvm.ptr, i64) -> !llvm.ptr, f64
    llvm.store %0, %20 : f64, !llvm.ptr
    %21 = llvm.mlir.addressof @frmt_spec : !llvm.ptr
    %22 = llvm.mlir.constant(0 : i64) : i64
    %23 = llvm.getelementptr %21[%22, %22] : (!llvm.ptr, i64, i64) -> !llvm.ptr, !llvm.array<4 x i8>
    %24 = llvm.mlir.addressof @nl : !llvm.ptr
    %25 = llvm.mlir.constant(0 : i64) : i64
    %26 = llvm.getelementptr %24[%25, %25] : (!llvm.ptr, i64, i64) -> !llvm.ptr, !llvm.array<2 x i8>
    %27 = llvm.mlir.constant(0 : index) : i64
    %28 = llvm.mlir.constant(2 : index) : i64
    %29 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb1(%27 : i64)
  ^bb1(%30: i64):  // 2 preds: ^bb0, ^bb2
    %31 = llvm.icmp "slt" %30, %28 : i64
    llvm.cond_br %31, ^bb2, ^bb3
  ^bb2:  // pred: ^bb1
    %32 = llvm.extractvalue %14[1] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    %33 = llvm.getelementptr inbounds|nuw %32[%30] : (!llvm.ptr, i64) -> !llvm.ptr, f64
    %34 = llvm.load %33 : !llvm.ptr -> f64
    %35 = llvm.call @printf(%23, %34) vararg(!llvm.func<i32 (ptr, ...)>) : (!llvm.ptr, f64) -> i32
    %36 = llvm.add %30, %29 : i64
    llvm.br ^bb1(%36 : i64)
  ^bb3:  // pred: ^bb1
    %37 = llvm.extractvalue %14[0] : !llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>
    llvm.call @free(%37) : (!llvm.ptr) -> ()
    llvm.return
  }
}
```

Every op of the Affine module has become `llvm` ops:

- **The declarations.** `@malloc` and `@free` are declared by the `memref` patterns. `@printf` and the two strings,
  `@frmt_spec` (`"%f "`) and `@nl` (a newline), are made by the `toy.print` pattern of this chapter. All five are at the
  top of the module.
- **The constants.** `arith.constant` is `llvm.mlir.constant`, and the type `index` is `i64`.
- **`memref.alloc`.** The lowering needs the size in bytes: it takes the address that the element count would reach from a
  null pointer (`llvm.mlir.zero`, `llvm.getelementptr`, `llvm.ptrtoint`) and calls `@malloc` with it. The result is
  put into a descriptor, the `!llvm.struct<(ptr, ptr, i64, array<1 x i64>, array<1 x i64>)>`: the allocated pointer, the
  aligned pointer, the offset, the sizes and the strides, filled in with `llvm.insertvalue`. From here on, a `memref` is
  that struct.
- **`affine.store`.** `llvm.extractvalue %14[1]` takes the aligned pointer out of the descriptor, `llvm.getelementptr`
  adds the index, and `llvm.store` stores.
- **`toy.print`.** `llvm.mlir.addressof` and `llvm.getelementptr` make the pointer to the first character of each string.
  Then comes the loop, as blocks: `llvm.br ^bb1(%27 : i64)` enters it with the first index, `^bb1` compares the index with
  the bound (`llvm.icmp`) and `llvm.cond_br` goes to the body `^bb2` or to the exit `^bb3`, and `^bb2` loads the element,
  calls `@printf` with the format and the element, adds one and branches back. This loop was an `scf.for`, and the
  conversion made it `cf` and then `llvm`.
- **`memref.dealloc`.** `llvm.extractvalue %14[0]` takes the allocated pointer and `llvm.call @free` frees it.

### `example.toy`: LLVM IR and the JIT

`--emit=llvm` translates the LLVM dialect to LLVM IR. Without `--opt` the translation is instruction by instruction,
like the module above. With `--opt`, LLVM's O3 pipeline runs on it, and since every value of `example.toy` is a constant,
LLVM computes `e` while it compiles. This is the whole module (the `sed` leaves out the debug metadata that follows it,
see below):

```sh
./toyc example.toy --emit=llvm --opt | sed '/^!llvm.dbg.cu/,$d'
```

```llvm
; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@frmt_spec = internal constant [4 x i8] c"%f \00"

; Function Attrs: nofree nounwind
declare !dbg !3 noundef i32 @printf(ptr noundef readonly captures(none), ...) local_unnamed_addr #0

; Function Attrs: nofree nounwind
define void @main() local_unnamed_addr #0 !dbg !6 {
.preheader3:
  %0 = tail call i32 (ptr, ...) @printf(ptr nonnull dereferenceable(1) @frmt_spec, double 1.000000e+00), !dbg !8
  %1 = tail call i32 (ptr, ...) @printf(ptr nonnull dereferenceable(1) @frmt_spec, double 1.600000e+01), !dbg !8
  %2 = tail call i32 (ptr, ...) @printf(ptr nonnull dereferenceable(1) @frmt_spec, double 8.100000e+01), !dbg !8
  %putchar = tail call i32 @putchar(i32 10), !dbg !8
  %3 = tail call i32 (ptr, ...) @printf(ptr nonnull dereferenceable(1) @frmt_spec, double 2.560000e+02), !dbg !8
  %4 = tail call i32 (ptr, ...) @printf(ptr nonnull dereferenceable(1) @frmt_spec, double 6.250000e+02), !dbg !8
  %5 = tail call i32 (ptr, ...) @printf(ptr nonnull dereferenceable(1) @frmt_spec, double 1.296000e+03), !dbg !8
  %putchar.1 = tail call i32 @putchar(i32 10), !dbg !8
  ret void, !dbg !11
}

; Function Attrs: nofree nounwind
declare noundef i32 @putchar(i32 noundef) local_unnamed_addr #0

attributes #0 = { nofree nounwind }
```

The buffers and the loops are gone. What is left is six calls of `printf` with the six numbers of `e` and a `putchar` of a
newline after each row. The `target` lines are those of the host that ran the command, here x86-64 Linux.

Every instruction ends with `!dbg !N`. The debug scope that these refer to is what step 9 made: for each `llvm.func` it
makes a `DISubprogram`, and that is what MLIR needs to turn the locations of the ops into line tables. The locations are
those of the Toy source, `example.toy`, because the front end gave each op the position it was written at and the
lowerings and the inliner kept them, with two exceptions that "Differences from C++" below explains. The files that the
metadata names are:

```sh
./toyc example.toy --emit=llvm --opt | grep -o 'DIFile(filename: "[^"]*"'
```

```text
DIFile(filename: "<unknown>"
DIFile(filename: "example.toy"
DIFile(filename: "lower-to-affine.sls"
```

`lower-to-affine.sls` is one of the two exceptions.

`--emit=jit` compiles the module in the process and calls `@main`. The program's own output goes to standard output:

```sh
./toyc example.toy --emit=jit
```

```text
1.000000 16.000000 81.000000
256.000000 625.000000 1296.000000
```

`--emit=jit --opt` prints the same.

### The shape of the printed output: `print-ranks.toy`

The `toy.print` pattern makes one loop for each dimension of the array. A loop prints a newline after each of its
iterations, except the innermost loop, which prints only the elements. So a plane of a rank 3 array is followed by a blank
line, a rank 2 array has one row for each line, and a rank 1 array is on one line that has no newline at its end. The C++
tutorial does the same (`if (i != e - 1)`). `print-ranks.toy` prints a rank 3, a rank 2 and a rank 1 array:

```text
def main() {
  var a = [[[1, 2], [3, 4]], [[5, 6], [7, 8]]];
  print(a);
  var b = [[1, 2, 3], [4, 5, 6]];
  print(b);
  var c = [1, 2, 3];
  print(c);
}
```

```sh
./toyc print-ranks.toy --emit=jit
```

```text
1.000000 2.000000
3.000000 4.000000

5.000000 6.000000
7.000000 8.000000

1.000000 2.000000 3.000000
4.000000 5.000000 6.000000
1.000000 2.000000 3.000000
```

The last line has no newline at its end.

### Take one pass out

Delete one line of `%%run-pipeline!` in `toyc.sls` and run the action again:

| Line removed | Command | What you see |
|---|---|---|
| `(toy:lower-to-llvm-pass)` | `--emit=mlir-llvm --opt` | the module of Ch5: `affine.store`, `memref.alloc` and a `toy.print` on a `memref`, and no `llvm` op |
| `(toy:lower-to-llvm-pass)` | `--emit=jit` | no output, and `toyc` exits with status 1: `Failed to create the execution engine: could not convert to LLVM IR`, because there is no `llvm.func`, only a `func.func` |
| `(mlir::LLVM::createDIScopeForLLVMFuncOpPass)` | `--emit=llvm --opt` | the same instructions, with no `!dbg` and no `DISubprogram` |
| `(mlir::LLVM::createDIScopeForLLVMFuncOpPass)` | `--emit=mlir-llvm` and `--emit=jit` | the same output: the printed module does not show the scope, and the program prints the same |

### One pattern set at a time

The LLVM lowering is one full conversion. Every `populate...Patterns` call in `:populate` adds the patterns for one
dialect, and the other calls and the pattern of `toy.print` depend on it: an `affine.for` becomes an `scf.for`, an
`scf.for` becomes `cf` blocks, `cf` becomes `llvm`. Delete one line of `%%toy-to-llvm-lower!` in `lower-to-llvm.sls` and
run `./toyc example.toy --emit=mlir-llvm --opt` again. The conversion fails, `toyc` prints `Optimization pipeline failed`
and exits with status 4, and the error names the first op that the conversion could not legalize:

| Line removed | The error |
|---|---|
| `(mlir::populateAffineToStdConversionPatterns patterns)` | `failed to legalize operation 'affine.store'` |
| `(mlir::populateSCFToControlFlowConversionPatterns patterns)` | `failed to legalize operation 'affine.for'` |
| `(mlir::arith::populateArithToLLVMConversionPatterns tc patterns)` | `failed to legalize operation 'arith.constant'` |
| `(mlir::populateFinalizeMemRefToLLVMConversionPatterns tc patterns)` | `failed to legalize operation 'memref.alloc'` |
| `(mlir::cf::populateControlFlowToLLVMConversionPatterns tc patterns)` | `failed to legalize operation 'affine.for'` |
| `(mlir::populateFuncToLLVMConversionPatterns tc patterns)` | `failed to legalize operation 'func.func'` |
| the pattern of `toy.print` (`("toy.print" %%print-lower! :no-type-converter)`) | `failed to legalize operation 'toy.print'` |

Without the `scf` or the `cf` patterns the loop cannot reach `llvm`, and the conversion reports the `affine.for` that it
started from.

Because the conversion is all or nothing, each of these makes the same tests fail: every test that lowers to LLVM,
`action-mlir-llvm-example.mlir`, `action-mlir-llvm-print.mlir`, `action-llvm-example.mlir`, `action-llvm-opt-example.mlir`,
`action-llvm-target-example.mlir`, and the three that run the JIT, `action-jit-example.mlir`, `action-jit-print-ranks.mlir`
and `action-jit-print-shapes.mlir`. Removing `(toy:lower-to-llvm-pass)` fails the same tests. Removing the DI scope pass,
step 9, fails only `action-llvm-example.mlir`, the test that looks for `!dbg`. `:illegal-dialects ("toy")` can be removed
without failing anything: a full conversion makes every op that is not legal illegal, so the line says what the target is,
and the conversion does not need it.

Two more tests check what a program that cannot run does. `action-jit-no-main.mlir` has no `main`: the engine is made and
the call of `main` fails, so `toyc` says `JIT invocation failed: Symbols not found: [ _mlir_main ]` and exits with
status 1. The two tests of Ch5 for a lowering that cannot finish, `lowering-main-arguments.mlir` and `lowering-failure.mlir`, are
here too.

## What you learn about MLIR here

Ch5 changed the abstraction level from Toy ops to `affine`, `arith`, `memref` and `func`. Ch6 goes down to the LLVM
dialect, where MLIR has a translation to LLVM IR and an execution engine.

The links are permalinks: the Scheme files of this chapter at the commit `497d697d9eb5` of this repository, and the C++ files of
the LLVM Toy tutorial at the commit `392dfff97d29` of LLVM.

1. **A full conversion has a target where only the `llvm` dialect is legal, and fails if any other op is left.** The target of
   Ch5 was partial: the ops that stayed legal were left alone. Here the `llvm` dialect and the `builtin.module` are
   legal, and everything else must be converted, `toy.print` included.
   - Scheme: [`apply-conversion` (`lower-to-llvm.sls` L174-L192)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/lower-to-llvm.sls#L174-L192), [the pass (`lower-to-llvm.sls` L194-L198)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/lower-to-llvm.sls#L194-L198)
   - C++: [the pass, the target and `applyFullConversion` (`LowerToLLVM.cpp` L180-L238)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp#L180-L238)
2. **A type converter changes the types with the ops.** The `LLVMTypeConverter` maps `index` to `i64` and a `memref` to
   the descriptor struct, and the patterns of `arith`, `memref`, `cf` and `func` use it to convert operands and results.
   The pattern of `toy.print` does not (`:no-type-converter`): it needs the original `memref` type, to read the shape that
   its loops go over.
   - Scheme: [`:converter`, `:legal-dialects`, `:legal-ops` (`lower-to-llvm.sls` L174-L181)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/lower-to-llvm.sls#L174-L181)
   - C++: [`LLVMConversionTarget` and `LLVMTypeConverter` (`LowerToLLVM.cpp` L193-L205)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp#L193-L205)
3. **MLIR has the patterns for its own dialects, and a lowering is a chain of them.** `toyc` does not write the lowering
   of `affine`, `scf`, `arith`, `memref`, `cf` or `func`: it adds the pattern sets of MLIR with `populate...Patterns`.
   One conversion runs the chain, `affine` to `scf` to `cf` to `llvm`, until only legal ops are left (the transitive
   lowering that the C++ comment names).
   - Scheme: [`:populate` (`lower-to-llvm.sls` L186-L192)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/lower-to-llvm.sls#L186-L192)
   - C++: [the `populate...Patterns` calls (`LowerToLLVM.cpp` L215-L221)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp#L215-L221)
4. **An op that no pattern of MLIR knows needs a pattern of its own.** `toy.print` becomes a loop nest that loads each
   element and calls `printf`. The loop is written with `scf.for`, and the conversion lowers it with the rest.
   - Scheme: [`%%call-printf!`, `%%emit-print-nest!` and `%%print-lower!` (`lower-to-llvm.sls` L117-L168)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/lower-to-llvm.sls#L117-L168)
   - C++: [`PrintOpLowering::matchAndRewrite` (`LowerToLLVM.cpp` L62-L118)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp#L62-L118)
5. **A pattern gets or inserts the symbols it uses at the start of the module.** The declaration of `printf` and the two
   strings are looked up in the module and made only when they are not there, with the insertion point moved to the start
   of the module, and put back when that is done (`InsertionGuard`).
   - Scheme: [`%%printf-type` and `%%get-or-insert-printf!` (`lower-to-llvm.sls` L50-L75)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/lower-to-llvm.sls#L50-L75), [`%%get-or-create-global-string!` and `%%global-string-ptr!` (`lower-to-llvm.sls` L77-L115)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/lower-to-llvm.sls#L77-L115)
   - C++: [`getPrintfType` and `getOrInsertPrintf` (`LowerToLLVM.cpp` L121-L145)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp#L121-L145), [`getOrCreateGlobalString` (`LowerToLLVM.cpp` L147-L172)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp#L147-L172)
6. **From the LLVM dialect MLIR translates to LLVM IR, and LLVM's optimizer takes over.** `translateModuleToLLVMIR` makes
   the LLVM module, and `--opt` runs LLVM's O3 on it, which is what folded `e` to six constants above. Step 9 gives each
   function the debug scope that line tables need.
   - Scheme: [`%%dump-llvm` (`toyc.sls` L139-L142)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/toyc.sls#L139-L142), [the LLVM lowering and the DI scope pass (`toyc.sls` L210-L212)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/toyc.sls#L210-L212)
   - C++: [`dumpLLVMIR` (`toyc.cpp` L214-L256)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/toyc.cpp#L214-L256), [the same two passes (`toyc.cpp` L186-L193)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/toyc.cpp#L186-L193)
7. **The same module runs in the process.** The `ExecutionEngine` compiles the module and `invoke` calls `main`. The
   program's `printf` is found in the process, which is why the output of the program is the output of `toyc`.
   - Scheme: [`%%run-jit` (`toyc.sls` L166-L173)](https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/toyc.sls#L166-L173)
   - C++: [`runJit` (`toyc.cpp` L258-L289)](https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/toyc.cpp#L258-L289)

## What's new over Ch5

| Feature | Ch5 | Ch6 |
|---|---|---|
| Actions | `ast`, `mlir`, `mlir-affine` | + `mlir-llvm`, `llvm`, `jit` |
| `toy.print` | the operand becomes a `memref`, the op is kept | lowered to an `scf.for` nest that calls `printf` |
| Lowering target | `affine`, `arith`, `memref`, `func` | the LLVM dialect only |
| Post-lowering passes | canonicalize + CSE | + the DI scope pass |
| Back ends | — | LLVM IR translation, the JIT |

`lower-to-affine.sls` is the file of Ch5, only its library name differs.

### Conversion patterns (`lower-to-llvm.sls`)

| Source | Pattern set | Result |
|---|---|---|
| `affine.*` | `populateAffineToStdConversionPatterns` | `arith` + `scf` |
| `scf.*` | `populateSCFToControlFlowConversionPatterns` | `cf.br` / `cf.cond_br` |
| `arith.*` | `populateArithToLLVMConversionPatterns` | `llvm.*` arithmetic |
| `memref.*` | `populateFinalizeMemRefToLLVMConversionPatterns` | `llvm.call @malloc/@free`, descriptor `insertvalue`/`extractvalue` |
| `cf.*` | `populateControlFlowToLLVMConversionPatterns` | `llvm.br` / `llvm.cond_br` |
| `func.*` | `populateFuncToLLVMConversionPatterns` | `llvm.func` / `llvm.return` |
| `toy.print` | the pattern of this chapter (`%%print-lower!`) | an `scf.for` nest with `memref.load` and `llvm.call @printf`, lowered by the other sets |

`%%print-lower!` is a `define-conversion-pattern` with `:no-type-converter`. Every op it creates is a `begin-mlir-code`
form: each `scf.for` is an op form whose body is a `{ ^body ... }` region, so the ops of the inner loops land inside it,
and `memref.load`, `llvm.func`, `llvm.mlir.global`, `llvm.mlir.addressof`, `llvm.getelementptr` and the variadic
`llvm.call` are op forms too. No typed builder is called, so the attributes that a typed builder fills in by default are
written out: the linkage and the calling convention of `llvm.func`, the linkage and the `constant` flag of
`llvm.mlir.global`, the `rawConstantIndices` and the `elem_type` of `llvm.getelementptr` (`-2147483648` is a dynamic
index), and for the call its `callee`, `var_callee_type`, `operandSegmentSizes` and `op_bundle_sizes`. The format strings
have an embedded NUL, which is why the globals are made with `mlir::StringAttr::get<StringRef>`, the call that takes the
length, instead of the plain `StringAttr::get`.

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect, the front end, shape inference, inlining and the affine lowering | as in Ch5 | `lower-to-affine.sls` is the file of Ch5 |
| `toy.print` lowered to a `printf` loop nest | `define-conversion-pattern`, with every op a `begin-mlir-code` form | see the section below: no typed builder is left |
| Registering the LLVM conversion | `apply-conversion` (`:converter (with-LLVMTypeConverter ...)`, `:legal-dialects`, `:legal-ops`, `:illegal-dialects`, `:patterns` with `:no-type-converter`, `:populate`) | one declaration instead of a target, a type converter and a pattern set made and freed by hand; the six `populate...Patterns` calls go in `:populate` |

## Why the lowering is written as it is

The C++ tutorial writes the lowering in `LowerToLLVM.cpp`: a `PrintOpLowering` pattern with three helper functions, and a
pass that builds a `LLVMConversionTarget`, a `LLVMTypeConverter` and a `RewritePatternSet`. The pipeline and the two back
ends are in `toyc.cpp`. `lower-to-llvm.sls` has the same pieces: one `define-conversion-pattern`, the same helpers as
functions, and a pass that is one `apply-conversion`. Here they are, piece to piece. The titles of the tables are
permalinks, with the lines of the code: the C++ files at the commit of LLVM they were taken from (`392dfff97d29`), and the
Scheme files at the commit `497d697d9eb5` of this repository. A later change to the Scheme files does not move them.

### The pass and its conversion target

<table>
<tr><th>C++, comments left out (<code>LowerToLLVM.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp#L180-L238">L180-L238</a>)</th><th>CREST DSL, comments left out (<code>lower-to-llvm.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/lower-to-llvm.sls#L174-L198">L174-L198</a>)</th></tr>
<tr><td>

```cpp
namespace {
struct ToyToLLVMLoweringPass
    : public PassWrapper<ToyToLLVMLoweringPass, OperationPass<ModuleOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(ToyToLLVMLoweringPass)
  StringRef getArgument() const override { return "toy-to-llvm"; }

  void getDependentDialects(DialectRegistry &registry) const override {
    registry.insert<LLVM::LLVMDialect, scf::SCFDialect>();
  }
  void runOnOperation() final;
};
} // namespace

void ToyToLLVMLoweringPass::runOnOperation() {
  LLVMConversionTarget target(getContext());
  target.addLegalOp<ModuleOp>();

  LLVMTypeConverter typeConverter(&getContext());

  RewritePatternSet patterns(&getContext());
  populateAffineToStdConversionPatterns(patterns);
  populateSCFToControlFlowConversionPatterns(patterns);
  mlir::arith::populateArithToLLVMConversionPatterns(typeConverter, patterns);
  populateFinalizeMemRefToLLVMConversionPatterns(typeConverter, patterns);
  cf::populateControlFlowToLLVMConversionPatterns(typeConverter, patterns);
  populateFuncToLLVMConversionPatterns(typeConverter, patterns);

  patterns.add<PrintOpLowering>(&getContext());

  auto module = getOperation();
  if (failed(applyFullConversion(module, target, std::move(patterns))))
    signalPassFailure();
}

std::unique_ptr<mlir::Pass> mlir::toy::createLowerToLLVMPass() {
  return std::make_unique<ToyToLLVMLoweringPass>();
}
```

</td><td>

```scheme
(define (%%toy-to-llvm-lower! module-op ctx)
  (apply-conversion module-op ctx
                    :converter (with-LLVMTypeConverter type-converter (ctx))
                    :legal-dialects ("llvm")
                    :legal-ops ("builtin.module")
                    :illegal-dialects ("toy")
                    :patterns (("toy.print" %%print-lower! :no-type-converter))
                    :populate (lambda (tc patterns)
                                (mlir::populateAffineToStdConversionPatterns patterns)
                                (mlir::populateSCFToControlFlowConversionPatterns patterns)
                                (mlir::arith::populateArithToLLVMConversionPatterns tc patterns)
                                (mlir::populateFinalizeMemRefToLLVMConversionPatterns tc patterns)
                                (mlir::cf::populateControlFlowToLLVMConversionPatterns tc patterns)
                                (mlir::populateFuncToLLVMConversionPatterns tc patterns))))

(define-pass (toy:lower-to-llvm-pass module)
  (let ([ctx (mlir::Operation::getContext module)])
    (with-current-MLIRContext ctx
      (%%toy-to-llvm-lower! module ctx))))
```

</td></tr>
</table>

Both say the same things: the `llvm` dialect and the module are legal, the type converter, and the six pattern sets. C++
says them with a target, a type converter, a `RewritePatternSet` and `applyFullConversion`, and signals the failure of the
pass itself. The DSL says them as keys of one `apply-conversion` form, and the pass has nothing else in it. The pattern of
`toy.print` is in `:patterns` in the DSL and is added with `patterns.add` in C++. The C++ pass also lists the dialects it
creates ops of (`getDependentDialects`); the DSL registers them where `toyc.sls` builds the context.

### The `toy.print` pattern

<table>
<tr><th>C++, comments left out (<code>LowerToLLVM.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp#L64-L118">L64-L118</a>)</th><th>CREST DSL, comments left out (<code>lower-to-llvm.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/lower-to-llvm.sls#L117-L168">L117-L168</a>)</th></tr>
<tr><td>

```cpp
class PrintOpLowering : public OpConversionPattern<toy::PrintOp> {
public:
  using OpConversionPattern<toy::PrintOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(toy::PrintOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto *context = rewriter.getContext();
    auto memRefType = llvm::cast<MemRefType>((*op->operand_type_begin()));
    auto memRefShape = memRefType.getShape();
    auto loc = op->getLoc();

    ModuleOp parentModule = op->getParentOfType<ModuleOp>();

    auto printfRef = getOrInsertPrintf(rewriter, parentModule);
    Value formatSpecifierCst = getOrCreateGlobalString(
        loc, rewriter, "frmt_spec", StringRef("%f \0", 4), parentModule);
    Value newLineCst = getOrCreateGlobalString(
        loc, rewriter, "nl", StringRef("\n\0", 2), parentModule);

    SmallVector<Value, 4> loopIvs;
    for (unsigned i = 0, e = memRefShape.size(); i != e; ++i) {
      auto lowerBound = arith::ConstantIndexOp::create(rewriter, loc, 0);
      auto upperBound =
          arith::ConstantIndexOp::create(rewriter, loc, memRefShape[i]);
      auto step = arith::ConstantIndexOp::create(rewriter, loc, 1);
      auto loop =
          scf::ForOp::create(rewriter, loc, lowerBound, upperBound, step);
      for (Operation &nested : make_early_inc_range(*loop.getBody()))
        rewriter.eraseOp(&nested);
      loopIvs.push_back(loop.getInductionVar());

      rewriter.setInsertionPointToEnd(loop.getBody());

      if (i != e - 1)
        LLVM::CallOp::create(rewriter, loc, getPrintfType(context), printfRef,
                             newLineCst);
      scf::YieldOp::create(rewriter, loc);
      rewriter.setInsertionPointToStart(loop.getBody());
    }

    auto elementLoad =
        memref::LoadOp::create(rewriter, loc, op.getInput(), loopIvs);
    LLVM::CallOp::create(rewriter, loc, getPrintfType(context), printfRef,
                         ArrayRef<Value>({formatSpecifierCst, elementLoad}));

    rewriter.eraseOp(op);
    return success();
  }
```

</td><td>

```scheme
(define (%%call-printf! loc ctx printf-ref args)
  (let ([fnty (%%printf-type ctx)]
        [i32  (mlir::IntegerType::get<i32> ctx)])
    (begin-mlir-code
        ret = llvm.call (,@args)
        (callee : printf-ref)
        (var_callee_type : (mlir::TypeAttr::get fnty))
        (operandSegmentSizes : (list (length args) 0) :i32-array)
        (op_bundle_sizes : '() :i32-array)
        :loc loc -> i32)))

(define (%%emit-print-nest! loc ctx printf-ref fmt nl in shape)
  (let ([idx  (mlir::IndexType::get ctx)]
        [elem-type (mlir::MemRefType::getElementType (mlir::Value::getType in))])
    (let nest ([dims shape] [ivs '()])
      (if (null? dims)
          (begin-mlir-code
              elem = memref.load (in ,@(reverse ivs)) :loc loc -> elem-type
              (%%call-printf! loc ctx printf-ref (list fmt elem)))
          (begin-mlir-code
              lb = arith.constant () (value : 0 :index) :loc loc -> idx
              ub = arith.constant () (value : (car dims) :index) :loc loc -> idx
              st = arith.constant () (value : 1 :index) :loc loc -> idx
              scf.for (lb ub st)
              { ^body ((iv : idx))
                (nest (cdr dims) (cons iv ivs))
                (when (pair? (cdr dims))
                  (%%call-printf! loc ctx printf-ref (list nl)))
                scf.yield () :loc loc }
              :loc loc)))))

(define-conversion-pattern (%%print-lower! op operands-ref rw tc)
  :if-match
    toy.print (_)
  :then-let
    ([loc        (mlir::Operation::getLoc op)]
     [in         (mlir::Operation::getOperand op 0)]
     [ctx        (mlir::Operation::getContext op)]
     [module-op  (mlir::Operation::getParentOfType<ModuleOp> op)]
     [shape      (mlir::ShapedType::getShape (mlir::Value::getType in))]
     [printf-ref (%%get-or-insert-printf! rw module-op ctx)])
  :rewrite op :with
    fmt = (%%global-string-ptr! rw loc "frmt_spec" "%f \x00;" module-op ctx)
    nl  = (%%global-string-ptr! rw loc "nl" "\n\x00;" module-op ctx)
    (%%emit-print-nest! loc ctx printf-ref fmt nl in shape))
```

</td></tr>
</table>

Both read the original operand and its shape, make the two format strings, and make a loop for each dimension: the
innermost body loads one element and calls `printf`, and every other loop calls `printf` with the newline after its inner
loop. C++ makes each `scf.for` with a builder, which gives the loop a body with a `scf.yield` that the code then erases
(`make_early_inc_range`), and moves the insertion point into the body by hand. The DSL writes the loop as an op form with a
region, so the body is what is written in it and there is nothing to erase, and it recurses on the dimensions where C++
has a `for`. The cost is the attributes: `LLVM::CallOp::create` fills in the segment sizes and the bundle sizes, and the
DSL writes `operandSegmentSizes` and `op_bundle_sizes` in each `llvm.call`.

### The declaration of `printf`

<table>
<tr><th>C++, comments left out (<code>LowerToLLVM.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp#L121-L145">L121-L145</a>)</th><th>CREST DSL, comments left out (<code>lower-to-llvm.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/lower-to-llvm.sls#L50-L75">L50-L75</a>)</th></tr>
<tr><td>

```cpp
static LLVM::LLVMFunctionType getPrintfType(MLIRContext *context) {
  auto llvmI32Ty = IntegerType::get(context, 32);
  auto llvmPtrTy = LLVM::LLVMPointerType::get(context);
  auto llvmFnType = LLVM::LLVMFunctionType::get(llvmI32Ty, llvmPtrTy,
                                                /*isVarArg=*/true);
  return llvmFnType;
}

static FlatSymbolRefAttr getOrInsertPrintf(PatternRewriter &rewriter,
                                           ModuleOp module) {
  auto *context = module.getContext();
  if (module.lookupSymbol<LLVM::LLVMFuncOp>("printf"))
    return SymbolRefAttr::get(context, "printf");

  PatternRewriter::InsertionGuard insertGuard(rewriter);
  rewriter.setInsertionPointToStart(module.getBody());
  LLVM::LLVMFuncOp::create(rewriter, module.getLoc(), "printf",
                           getPrintfType(context));
  return SymbolRefAttr::get(context, "printf");
}
```

</td><td>

```scheme
(define (%%printf-type ctx)
  (mlir::LLVM::LLVMFunctionType::get ctx
                                     (mlir::IntegerType::get<i32> ctx)
                                     (mlir::LLVM::LLVMPointerType::get ctx)
                                     1))

(define (%%get-or-insert-printf! rw module-op ctx)
  (if (not (zero? (mlir::ModuleOp::lookupSymbol module-op "printf")))
      (mlir::FlatSymbolRefAttr::get ctx "printf")
      (let ([fnty (%%printf-type ctx)]
            [body (mlir::ModuleOp::getBody module-op)])
        (with-InsertionGuard guard (rw)
                             (mlir::RewriterBase::setInsertionPointToStart rw body)
                             (with-current-OpBuilder rw
                               (begin-mlir-code
                                   llvm.func ()
                                   (sym_name : "printf" :string)
                                   (function_type : (mlir::TypeAttr::get fnty))
                                   (linkage : (mlir::parseAttribute "#llvm.linkage<external>"))
                                   (CConv : (mlir::parseAttribute "#llvm.cconv<ccc>"))
                                   { }
                                   :loc (mlir::Operation::getLoc module-op))))
        (mlir::FlatSymbolRefAttr::get ctx "printf"))))
```

</td></tr>
</table>

Both look the symbol up in the module and insert the declaration at the start of the module, under an insertion guard,
only when it is not there. C++ gives the builder the name and the type and gets the linkage and the calling convention by
default. The DSL writes them (`linkage` and `CConv`) as attributes parsed from text, `#llvm.linkage<external>`, so a
misspelled name is found when the program runs, where a misspelled `LLVM::Linkage::External` in C++ is found when the
program is compiled.

### The global strings

<table>
<tr><th>C++, comments left out (<code>LowerToLLVM.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp#L147-L172">L147-L172</a>)</th><th>CREST DSL, comments left out (<code>lower-to-llvm.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/lower-to-llvm.sls#L77-L115">L77-L115</a>)</th></tr>
<tr><td>

```cpp
static Value getOrCreateGlobalString(Location loc, OpBuilder &builder,
                                     StringRef name, StringRef value,
                                     ModuleOp module) {
  LLVM::GlobalOp global;
  if (!(global = module.lookupSymbol<LLVM::GlobalOp>(name))) {
    OpBuilder::InsertionGuard insertGuard(builder);
    builder.setInsertionPointToStart(module.getBody());
    auto type = LLVM::LLVMArrayType::get(
        IntegerType::get(builder.getContext(), 8), value.size());
    global = LLVM::GlobalOp::create(builder, loc, type, /*isConstant=*/true,
                                    LLVM::Linkage::Internal, name,
                                    builder.getStringAttr(value),
                                    /*alignment=*/0);
  }

  Value globalPtr = LLVM::AddressOfOp::create(builder, loc, global);
  Value cst0 = LLVM::ConstantOp::create(builder, loc, builder.getI64Type(),
                                        builder.getIndexAttr(0));
  return LLVM::GEPOp::create(
      builder, loc, LLVM::LLVMPointerType::get(builder.getContext()),
      global.getType(), globalPtr, ArrayRef<Value>({cst0, cst0}));
}
```

</td><td>

```scheme
(define (%%get-or-create-global-string! rw loc name value module-op ctx)
  (let ([existing (mlir::ModuleOp::lookupSymbol module-op name)])
    (if (not (zero? existing))
        existing
        (let* ([len   (string-length value)]  ; includes embedded NUL
               [arrty (mlir::LLVM::LLVMArrayType::get (mlir::IntegerType::get<i8> ctx) len)]
               [attr  (mlir::StringAttr::get<StringRef> ctx value len)]
               [body  (mlir::ModuleOp::getBody module-op)])
          (with-InsertionGuard guard (rw)
                               (mlir::RewriterBase::setInsertionPointToStart rw body)
                               (with-current-OpBuilder rw
                                 (begin-mlir-code
                                     llvm.mlir.global ()
                                     (global_type : (mlir::TypeAttr::get arrty))
                                     (constant : #f :unit)
                                     (sym_name : name :string)
                                     (linkage : (mlir::parseAttribute "#llvm.linkage<internal>"))
                                     (value : attr)
                                     { }
                                     :loc loc)))))))

(define (%%global-string-ptr! rw loc name value module-op ctx)
  (let* ([global (%%get-or-create-global-string! rw loc name value module-op ctx)]
         [ptr    (mlir::LLVM::LLVMPointerType::get ctx)]
         [i64    (mlir::IntegerType::get<i64> ctx)]
         [arrty  (mlir::LLVM::GlobalOp::getType global)])
    (begin-mlir-code
        addr = llvm.mlir.addressof ()
        (global_name : (mlir::FlatSymbolRefAttr::get ctx name))
        :loc loc -> ptr
        zero = llvm.mlir.constant () (value : 0 :i64) :loc loc -> i64
        gep  = llvm.getelementptr (addr zero zero)
        (rawConstantIndices : '(-2147483648 -2147483648) :i32-array)
        (elem_type : (mlir::TypeAttr::get arrty))
        :loc loc -> ptr)))
```

</td></tr>
</table>

Both create the global at the start of the module if it is not there, then make the pointer to its first character with
`llvm.mlir.addressof` and a `getelementptr` with two zero indices. C++ passes the type, the linkage and the flag to
`GlobalOp::create`. The DSL writes `global_type`, `constant`, `linkage` and `value`, and in the `getelementptr` the
`rawConstantIndices` with the constant that MLIR uses for an index that is a value (`-2147483648`), which `GEPOp::create`
works out from the indices that it is given.

### The pipeline

<table>
<tr><th>C++, comments left out (<code>toyc.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/toyc.cpp#L144-L198">L144-L198</a>)</th><th>CREST DSL, comments left out (<code>toyc.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/toyc.sls#L194-L213">L194-L213</a>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/toyc.sls#L215-L218">L215-L218</a>)</th></tr>
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

The same sequence in both, as in Ch5, then the LLVM lowering and the DI scope pass when the action is `mlir-llvm` or
later. C++ chooses the steps with `isLoweringToAffine` and `isLoweringToLLVM` from the order of the actions. In the DSL
the action passes the two flags, and `%%dump-llvm` and `%%run-jit` always pass both.

### The translation to LLVM IR

<table>
<tr><th>C++, comments left out (<code>toyc.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/toyc.cpp#L214-L256">L214-L256</a>)</th><th>CREST DSL, comments left out (<code>toyc.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/toyc.sls#L139-L142">L139-L142</a>)</th></tr>
<tr><td>

```cpp
static int dumpLLVMIR(mlir::ModuleOp module) {
  mlir::registerBuiltinDialectTranslation(*module->getContext());
  mlir::registerLLVMDialectTranslation(*module->getContext());

  llvm::LLVMContext llvmContext;
  auto llvmModule = mlir::translateModuleToLLVMIR(module, llvmContext);
  if (!llvmModule) {
    llvm::errs() << "Failed to emit LLVM IR\n";
    return -1;
  }

  llvm::InitializeNativeTarget();
  llvm::InitializeNativeTargetAsmPrinter();

  auto tmBuilderOrError = llvm::orc::JITTargetMachineBuilder::detectHost();
  if (!tmBuilderOrError) {
    llvm::errs() << "Could not create JITTargetMachineBuilder\n";
    return -1;
  }

  auto tmOrError = tmBuilderOrError->createTargetMachine();
  if (!tmOrError) {
    llvm::errs() << "Could not create TargetMachine\n";
    return -1;
  }
  mlir::ExecutionEngine::setupTargetTripleAndDataLayout(llvmModule.get(),
                                                        tmOrError.get().get());

  auto optPipeline = mlir::makeOptimizingTransformer(
      /*optLevel=*/enableOpt ? 3 : 0, /*sizeLevel=*/0,
      /*targetMachine=*/nullptr);
  if (auto err = optPipeline(llvmModule.get())) {
    llvm::errs() << "Failed to optimize LLVM IR " << err << "\n";
    return -1;
  }
  llvm::errs() << *llvmModule << "\n";
  return 0;
}
```

</td><td>

```scheme
(with-mlir::OwningOpRef module-op (%%build-module filename ctx)
  (%%run-pipeline! module-op ctx opt? #t #t)
  (display (mlir::translateModuleToLLVMIR module-op (if opt? 3 0)))
  (newline)))))
```

</td></tr>
</table>

C++ registers the translations, makes the LLVM module, configures the target triple and the data layout of the host
(`setupTargetTripleAndDataLayout`), runs the optimizing pipeline, and prints. The DSL has one call, and `--opt` is the
level of the second argument: the target machine, the optimizer and the printing are inside the binding of
`mlir::translateModuleToLLVMIR`, which does what the C++ tutorial writes in `dumpLLVMIR`.

### The JIT

<table>
<tr><th>C++, comments left out (<code>toyc.cpp</code>, <a href="https://github.com/llvm/llvm-project/blob/392dfff97d29b59d77e5cac6d4b6ef2585fe7117/mlir/examples/toy/Ch6/toyc.cpp#L258-L289">L258-L289</a>)</th><th>CREST DSL, comments left out (<code>toyc.sls</code>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/toyc.sls#L166-L173">L166-L173</a>, <a href="https://github.com/wcy123/crest/blob/497d697d9eb54c14ed3538fd6616aef3a072a7a5/samples/toy/ch6/toyc.sls#L177-L185">L177-L185</a>)</th></tr>
<tr><td>

```cpp
static int runJit(mlir::ModuleOp module) {
  llvm::InitializeNativeTarget();
  llvm::InitializeNativeTargetAsmPrinter();

  mlir::registerBuiltinDialectTranslation(*module->getContext());
  mlir::registerLLVMDialectTranslation(*module->getContext());

  auto optPipeline = mlir::makeOptimizingTransformer(
      /*optLevel=*/enableOpt ? 3 : 0, /*sizeLevel=*/0,
      /*targetMachine=*/nullptr);

  mlir::ExecutionEngineOptions engineOptions;
  engineOptions.transformer = optPipeline;
  auto maybeEngine = mlir::ExecutionEngine::create(module, engineOptions);
  assert(maybeEngine && "failed to construct an execution engine");
  auto &engine = maybeEngine.get();

  auto invocationResult = engine->invokePacked("main");
  if (invocationResult) {
    llvm::errs() << "JIT invocation failed\n";
    return -1;
  }

  return 0;
}
```

</td><td>

```scheme
(with-mlir::OwningOpRef module-op (%%build-module filename ctx)
  (%%run-pipeline! module-op ctx opt? #t #t)
  (guard (e [(%%engine-error? e "mlir::ExecutionEngine::create")
             (%%quit-with "Failed to create the execution engine" e)]
            [(%%engine-error? e "mlir::ExecutionEngine::invoke")
             (%%quit-with "JIT invocation failed" e)])
    (with-ExecutionEngine engine (module-op (if opt? 3 0))
      (mlir::ExecutionEngine::invoke engine "main")))))))
```

```scheme
(define (%%engine-error? e who)
  (and (who-condition? e) (equal? (condition-who e) who)))

(define (%%quit-with message e)
  (display message (current-error-port))
  (display ": " (current-error-port))
  (display (condition-message e) (current-error-port))
  (newline (current-error-port))
  (%%quit 1))
```

</td></tr>
</table>

Both make the engine with the optimizer of O3 when `--opt` is given, and call `main`. C++ asserts that the engine was made
and prints `JIT invocation failed` when the call fails. The DSL turns each of the two failures of MLIR into a message that
has the text of MLIR and exits with status 1. `action-jit-no-main.mlir` checks the second.

### Differences from C++

- **Standard output.** C++ prints the LLVM IR to standard error (`llvm::errs()`). `--emit=llvm` here prints it to standard
  output, like `--emit=mlir-llvm`.
- **A translation that fails.** C++ prints `Failed to emit LLVM IR` and returns -1. Here the binding returns the text
  `(translation failed)` in place of the LLVM IR, so `toyc` prints that and exits with status 0. Remove `(toy:lower-to-llvm-pass)`
  and run `--emit=llvm` to see it. MLIR's own error is on standard error.
- **The location of two ops.** The `toy.print` update and the `return` of Ch5's lowering are written as `:rewrite` forms
  with no `:loc`, so their location is the position of the form in `lower-to-affine.sls`, where C++ keeps the location of
  the Toy op. The `!dbg` locations of those two name `lower-to-affine.sls`, and the locations of the other ops name
`example.toy`.

### What this adds up to

- **The lowering is mostly MLIR's.** Six of the seven pattern sets are MLIR's, added with one call each, and the chain
  from `affine` to `llvm` is run by one conversion. The only code of this chapter that makes IR is the pattern of
  `toy.print`.
- **A pattern is the IR it makes.** The `toy.print` loop is written as `scf.for`, `memref.load` and `llvm.call` forms, in
  the order and the nesting of the loops, where C++ makes each op with a call and a position of the builder.
- **The attributes are written out.** C++ gets the defaults of a typed builder, and the DSL writes the linkage, the
  segment sizes and the index constants. That is more text, and it shows what the op holds.
- **What C++ gives that the DSL does not here:** typed enums (`LLVM::Linkage::Internal`), which the compiler checks, and a
  failed translation that stops `toyc`.

## Related Documents

- [../ch5/README.md](../ch5/README.md) — Ch5 partial lowering to Affine
- [../ch4/inlining.md](../ch4/inlining.md) — how inlining works
