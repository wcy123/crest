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
inliner can inline `toy.generic_call` into its callers.

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

Other ops in `@foo` (non-alloca) would pass; only `memref.alloca` blocks
inlining here.

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

`materializeCallConversion` runs between steps 2 and 3 when the return type
and call-result type differ (ranked vs. unranked tensor): it inserts a
`toy.cast` so `handleTerminator` has a type-compatible value to substitute.

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

## How `toy.return` Is Recognised as a Terminator

`toy.return` has no `IsTerminator` trait — CREST's `define-op` DSL does not
yet support a `:traits` clause. Despite this, `Block::mightHaveTerminator()`
does not assert:

```cpp
// mlir/include/mlir/IR/OperationSupport.h
bool mightHaveTrait(TypeID traitID) const {
  return !isRegistered() || getImpl()->hasTrait(traitID);
}
```

CREST dynamic ops are not in MLIR's standard op registry (`isRegistered()`
returns `false`), so `mightHaveTrait` conservatively returns `true` for all
of them. `Block::getTerminator()` therefore passes its assertion and returns
`&back()` — the last op by position.

`toy.return` works as a terminator by convention: it is always written last
in a block. The correct fix is to register `IsTerminator` via a `:traits`
clause once the DSL supports it.
