# Toy Ch6 — Lowering to LLVM

Ch6 completes the lowering pipeline: everything left after Ch5's partial
lowering (`affine`, `arith`, `memref`, `func`, `scf`, plus `toy.print`) is
converted to the LLVM dialect. The result can be dumped as LLVM-dialect MLIR,
translated to LLVM IR, or executed directly with the MLIR `ExecutionEngine`.

## What's new over Ch5

| Feature | Ch5 | Ch6 |
|---|---|---|
| Actions | `ast`, `mlir`, `mlir-affine` | + `mlir-llvm`, `llvm`, `jit` |
| `toy.print` | kept as-is (operand now a memref) | lowered to `scf.for` nest + `llvm.call @printf` |
| Lowering target | Affine+Arith+MemRef+Func | LLVM dialect only |
| Post-lowering passes | canonicalize + CSE | + `ReconcileUnrealizedCasts` + `DIScopeForLLVMFuncOp` |
| Backends | — | LLVM IR translation, JIT (`ExecutionEngine`) |

`lower-to-affine.sls` is unchanged from Ch5 (only the library name differs).

### Conversion patterns (`lower-to-llvm.sls`)

`%%toy-to-llvm-lower!` runs one `apply-full-conversion` with an
`LLVMTypeConverter`. The `llvm` dialect and `builtin.module` are legal; the
`toy` dialect is illegal, so anything left over fails the conversion.

| Source | Pattern set | Result |
|---|---|---|
| `affine.*` | `populateAffineToStdConversionPatterns` | `arith` + `scf` |
| `scf.*` | `populateSCFToControlFlowConversionPatterns` | `cf.br` / `cf.cond_br` |
| `arith.*` | `populateArithToLLVMConversionPatterns` | `llvm.*` arithmetic |
| `memref.*` | `populateFinalizeMemRefToLLVMConversionPatterns` | `llvm.call @malloc/@free`, descriptor `insertvalue`/`extractvalue` |
| `cf.*` | `populateControlFlowToLLVMConversionPatterns` | `llvm.br` / `llvm.cond_br` |
| `func.*` | `populateFuncToLLVMConversionPatterns` | `llvm.func` / `llvm.return` |
| `toy.print` | custom (`%%print-lower!`) | see below |

### `toy.print` → `printf`

`%%print-lower!` is registered with `add-conversion-pattern/ctx` (no
`TypeConverter`), so it sees the original, unconverted memref operand and reads
its shape directly. For a memref of shape `d0 x d1 x ...` it emits:

1. `llvm.func @printf(!llvm.ptr, ...) -> i32`, declared on first use.
2. Two private global strings, created on first use:
   `@frmt_spec = "%f \0"` and `@nl = "\n\0"`.
3. One `scf.for` per dimension. The innermost body does `memref.load` followed
   by `llvm.call @printf(@frmt_spec, elem)`. Every loop except the innermost
   also calls `printf(@nl)` after its inner loop, so each row ends up on its
   own line.

The format strings contain an embedded NUL, which is why the globals are built
with `mlir::StringAttr::get/len` instead of a plain `StringAttr::get`.

Because the print loops are `scf`, they are lowered to `cf` and then to `llvm`
by the same conversion; nothing in this chapter needs a second pass.

### Pipeline (`toyc.sls`)

`--emit=mlir-llvm`, `--emit=llvm` and `--emit=jit` all run steps 1 to 6;
`--opt` only controls step 4.

1. **Inline** — Scheme-level `%%inline-calls!`, then drop private functions
2. **Shape inference** — Scheme walk per `toy.func`
3. **Canonicalize** — greedy rewrite (Ch3/Ch4 patterns)
4. **Affine lowering** — `%%toy-to-affine-lower!`, then canonicalize + CSE on
   `func.func`; with `--opt`, also loop fusion + affine scalar replacement
5. **LLVM lowering** — `%%toy-to-llvm-lower!`
6. **Cleanup** — `createReconcileUnrealizedCastsPass`, then
   `LLVM::createDIScopeForLLVMFuncOpPass`

`ReconcileUnrealizedCasts` cleans up `builtin.unrealized_conversion_cast` ops
that the `LLVMTypeConverter` can leave behind. `DIScopeForLLVMFuncOp` attaches
a debug-info scope (`DISubprogram`) to each `llvm.func`, which is why the
`--emit=llvm` output carries `!dbg` annotations.

### Actions

| Action | Output |
|---|---|
| `--emit=mlir-llvm` | the module in the LLVM dialect, printed as MLIR |
| `--emit=llvm` | `mlir::translateModuleToLLVMIR` — textual LLVM IR |
| `--emit=jit` | runs `@main` through `ExecutionEngine::invoke`; the program's own `print` output goes to stdout |

## Commands

```sh
# Dump the AST
./toyc example.toy --emit=ast

# Raw Toy MLIR (no optimization)
./toyc example.toy --emit=mlir

# Partially lowered to Affine+Arith+MemRef+Func
./toyc example.toy --emit=mlir-affine --opt

# Fully lowered to the LLVM dialect
./toyc example.toy --emit=mlir-llvm --opt

# Translated to textual LLVM IR
./toyc example.toy --emit=llvm --opt

# Compile and run
./toyc example.toy --emit=jit --opt
```

Running `example.toy` with `--emit=jit` prints the 2x3 result of the last
`print(e)`, one row per line:

```
1.000000 16.000000 81.000000
256.000000 625.000000 1296.000000
```

## Related Documents

- [../ch5/README.md](../ch5/README.md) — Ch5 partial lowering to Affine
- [../ch4/inlining.md](../ch4/inlining.md) — how inlining works
