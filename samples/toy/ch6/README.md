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
| Post-lowering passes | canonicalize + CSE | + `DIScopeForLLVMFuncOp` |
| Backends | — | LLVM IR translation, JIT (`ExecutionEngine`) |

`lower-to-affine.sls` is unchanged from Ch5 (only the library name differs).

### Conversion patterns (`lower-to-llvm.sls`)

`toy:lower-to-llvm-pass` is a `define-pass` around one `apply-conversion` (full mode) with an
`LLVMTypeConverter` (`:converter (with-LLVMTypeConverter type-converter (ctx))`). The `llvm` dialect and `builtin.module` are legal; the
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

`%%print-lower!` is a `define-conversion-pattern`, registered with
`:no-type-converter` (no `TypeConverter`). It reads the original memref
operand from the op, not the converted one, and takes its shape from that
operand's type. Every op is written with `begin-mlir-code`, so none is created
by a typed builder: each `scf.for` is an op-form whose body is a `^body` block,
so the ops of the inner loops land inside it, and `memref.load`, `llvm.func`,
`llvm.mlir.global`, `llvm.mlir.addressof`, `llvm.getelementptr` and the variadic
`llvm.call` are op-forms too. The ops that typed builders would fill in by
default are spelled out as attributes: the linkage and calling convention of
`llvm.func`, the linkage and `constant` flag of `llvm.mlir.global`, the
`rawConstantIndices` and `elem_type` of `llvm.getelementptr` (a dynamic index is
`-2147483648`), and for the call its `callee`, `var_callee_type`,
`operandSegmentSizes` and `op_bundle_sizes`. The helpers that declare `@printf`
and the globals insert at the start of the module under an `InsertionGuard`,
which restores the insertion point when they return. For a memref of shape
`d0 x d1 x ...` it emits:

1. `llvm.func @printf(!llvm.ptr, ...) -> i32`, declared on first use.
2. Two private global strings, created on first use:
   `@frmt_spec = "%f \0"` and `@nl = "\n\0"`.
3. One `scf.for` per dimension. The innermost body does `memref.load` followed
   by `llvm.call @printf(@frmt_spec, elem)`. Every loop except the innermost
   also calls `printf(@nl)` after its inner loop, so each row ends up on its
   own line.

The format strings contain an embedded NUL, which is why the globals are built
with `mlir::StringAttr::get<StringRef>` instead of a plain `StringAttr::get`.

Because the print loops are `scf`, they are lowered to `cf` and then to `llvm`
by the same conversion; nothing in this chapter needs a second pass.

### Pipeline (`toyc.sls`)

`--emit=mlir-llvm`, `--emit=llvm` and `--emit=jit` all run steps 1 to 6;
`--opt` only controls step 4.

1. **Inline** — MLIR's inliner pass, which also drops the private functions
2. **Shape inference** — rewrite patterns (`shape-inference.sls`), as in Ch4
3. **Canonicalize + CSE** — nested on `toy.func` (Ch3/Ch4 patterns, dead ops, common subexpressions)
4. **Affine lowering** — `toy:lower-to-affine-pass`, then canonicalize + CSE on
   `func.func`; with `--opt`, also loop fusion + affine scalar replacement
5. **LLVM lowering** — `toy:lower-to-llvm-pass`
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
| `--emit=llvm` | `mlir::translateModuleToLLVMIR` — textual LLVM IR with the host's target triple and data layout; `--opt` also runs LLVM's O3 pipeline (`makeOptimizingTransformer`), as the C++ `dumpLLVMIR` does |
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

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| Everything in Ch5 | as in the Ch5 README | `lower-to-affine.sls` is unchanged |
| `toy.print` lowered to a `printf` loop nest | `define-conversion-pattern`, with every op a `begin-mlir-code` form | see the section above: no typed builder is left |
| Registering the LLVM conversion | `apply-conversion` (`:converter (with-LLVMTypeConverter ...)`, `:legal-dialects`, `:legal-ops`, `:illegal-dialects`, `:patterns` with `:no-type-converter`, `:populate`) | the six `populate...Patterns` calls go in `:populate` |
| Shape inference | `define-rewrite-pattern`, as in Ch4 | |
| Inlining | MLIR's inliner pass, as in Ch4 | the dialect declares what the pass needs, see the Ch4 README |

## Related Documents

- [../ch5/README.md](../ch5/README.md) — Ch5 partial lowering to Affine
- [../ch4/inlining.md](../ch4/inlining.md) — how inlining works
