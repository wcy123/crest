<!--
Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
Licensed under the MIT License.
-->

**Date:** 2026-11-01
**Document Type:** Tech Note
**Status:** Draft
**Related:** [toy.sls](toy.sls)

# Ch4 Inlining — How `DialectInlinerInterface` Works

## Overview

Ch4 adds `DialectInlinerInterface` to the toy dialect so MLIR's generic
inliner can inline `toy.generic_call` into its callers; `toyc.sls` runs that pass.

## `isLegalToInline` — three-level gate

Before copying anything, the inliner calls three predicates in order.
All must return `true`; any `false` aborts inlining.

**1. Call-site gate** — asked once per call site:

```cpp
isLegalToInline(Operation* call, Operation* callable, bool wouldBeCloned)
```

`call` is the call op; `callable` is the function definition.
`wouldBeCloned` is `true` for multi-use callees (cloned), `false` for
single-use callees (moved). Guards coarse decisions such as call metadata
or cloning cost.

**2. Region gate** — asked once per region pair:

```cpp
isLegalToInline(Region* dest, Region* src, bool wouldBeCloned, IRMapping&)
```

Example: an `affine.for` body region requires every memory access inside it
to use an affine index expression. If the call site is inside such a loop:

```
affine.for %i = 0 to 10 {
  %r = call @foo(%mem, %i)        // inlining this
}
func @foo(%mem, %idx) {
  %0 = memref.load %mem[%idx]     // non-affine — index is a runtime value
  return %0
}
```

`isLegalToInline(dest=affine.for body, src=@foo body)` returns `false`:
inlining would place `memref.load` inside the affine region, breaking the
structural invariant the affine dialect relies on for polyhedral analysis.
It is up to the dialect to decide — `wouldBeCloned` and loop bounds are
irrelevant to the structural constraint.

**3. Per-op gate** — asked for every individual op in the callee body:

```cpp
isLegalToInline(Operation* op, Region* dest, bool wouldBeCloned, IRMapping&)
```

`op` is each individual op from the callee being considered for placement;
`dest` is the destination region it would land in.

Example: `memref.alloca` (stack allocation) — a dialect that lowers it to a
bare `llvm.alloca` without `stacksave`/`stackrestore` can only place it
in a function entry block. If the call site is inside a loop:

```
func.func @bar() {
  scf.for %i = 0 to 100 step 1 {
    call @foo()                         // inlining this
  }
}
func.func @foo() {
  %buf = memref.alloca() : memref<64xf32>   // stack allocation
  // use %buf
}
```

For `memref.alloca` the inliner calls:

```
op   = memref.alloca
dest = scf.for body region
```

The dialect returns `false` — placing a bare `alloca` inside the loop body
would grow the stack on every iteration with no release until the function
returns. A dialect that lowers `alloca` with `stacksave`/`stackrestore`
could return `true` for the same op. It is up to the dialect to decide.

The inliner walks every op in `@foo`'s body before copying anything.
If any single op returns `false`, the entire inlining is aborted — nothing
is copied. Other ops in `@foo` (non-alloca) would pass; only `memref.alloca`
blocks it, and the call site keeps its `call @foo()` unchanged.

In Toy all three always return `true` — no placement restrictions.

## How the Inliner Works

**Before** — two functions, one call site:

```
toy.func @multiply_transpose(%a, %b) {
  %t0     = toy.transpose(%a)
  %t1     = toy.transpose(%b)
  %result = toy.mul %t0, %t1
  toy.return %result
}
toy.func @main() {
  ...
  %r = toy.generic_call @multiply_transpose(%A, %B)
  toy.print %r
  toy.return
}
```

**Step 1 — copy** (`%a→%A`, `%b→%B`):

```
toy.func @main() {
  ...
  %r        = toy.generic_call @multiply_transpose(%A, %B)  ← still here
  %t0_c     = toy.transpose(%A)
  %t1_c     = toy.transpose(%B)
  %result_c = toy.mul %t0_c, %t1_c
  toy.return %result_c                                       ← cloned terminator
  toy.print %r                                               ← uses %r (valid)
  toy.return
}
```

**Step 2 — erase the call op**: `%r`'s definition disappears. `toy.print %r`
now has a **dangling** use — `%r` is consumed but no longer defined.

**Step 3 — `handleTerminator`**:

```
op             = toy.return %result_c   ; the cloned terminator
replacements   = [%r]                   ; the dangling call result
```

Invariant (enforced by MLIR's type system):
`len(replacements) == len(operands of op) == len(results of toy.generic_call) == len(return types of toy.func)`

For each `i`: `replaceAllUsesWith(replacements[i], operand(op, i))`,
i.e. `replaceAllUsesWith(%r, %result_c)`:

```
toy.print %r   →   toy.print %result_c
```

`%r` now has zero uses.

**Step 4 — cleanup**: erase the call op (`%r` unused) and the cloned
`toy.return`. Done:

```
toy.func @main() {
  ...
  %t0_c     = toy.transpose(%A)
  %t1_c     = toy.transpose(%B)
  %result_c = toy.mul %t0_c, %t1_c
  toy.print %result_c
  toy.return
}
```

**Step 2b — `materializeCallConversion`** (only when types differ):

If the return value type inside the callee doesn't match the call-site result
type, `replaceAllUsesWith` would be type-unsafe. The inliner calls:

```
materializeCallConversion(
  builder,
  input       = %result_c,      ; tensor<3x2xf64> — what the callee produced
  result-type = tensor<*xf64>,  ; what the call site expects
  loc)
```

This happens when shape inference has already run inside the callee
(resolving `tensor<*xf64>` → `tensor<3x2xf64>`) but the call site still
expects the unranked type. The toy dialect inserts a `toy.cast`:

```
%cast = toy.cast(%result_c : tensor<3x2xf64>) to tensor<*xf64>
```

`handleTerminator` then uses `%cast` (not `%result_c`) as the replacement
for `%r`. Shape inference (the next pipeline step) resolves and removes the
cast.

## Why `handleTerminator(op, ValueRange)` Is Dialect-Specific

For the common case the behavior is always the same: positional
`replaceAllUsesWith(valuesToRepl[i], op.getOperand(i))`. MLIR could
provide this as a default, and `DialectInlinerInterface` would be better
designed if it did. The reason a dialect needs a custom implementation:

- **Non-positional operand layout** — a return op with interleaved
  side-channel operands (e.g. `my.return %value, %token`). Only `%value`
  maps to a call result; the dialect must skip `%token`.
- **Aggregated returns** — one physical return operand holds N logical
  values as a struct. The dialect must extract each field before calling
  `replaceAllUsesWith`.
- **Post-replacement side effects** — symbol-table updates, cache
  invalidation, or runtime notifications after use redirection.

## `toy.return` as a Terminator

`toy.return` has no `IsTerminator` trait, because the Toy dialect is written for LLVM 22 and 23
and `define-op :traits (terminator)` needs `DynamicOpDefinition::addTrait`, which only LLVM 23 has.
Scheme dialects are registered ops, so MLIR does not guess: on any LLVM the verifier rejects a
block that ends in an op without the trait ("block with no terminator"). The Toy tools never
verify the IR they build, so this does not show. It is also why MLIR's inliner pass is not used here:
it verifies. With `:traits (terminator)` on `toy.return` (LLVM 23), and `CallOpInterface` on
`toy.generic_call` (available now), `--inline` works on a Scheme dialect: see
`test/dsl/call-op-interface`.
