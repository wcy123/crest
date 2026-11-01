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
inliner can inline `toy.generic_call` into its callers. This note explains
the five inlining steps and the two dialect callbacks that implement them.

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
op              = toy.return %result_c   ; the cloned terminator
n-replacements  = 1                      ; one call result to fix
replacements    = [%r]                   ; the dangling call result
```

Invariant (enforced by MLIR's type system):
`n-replacements == len(operands of op) == len(results of toy.generic_call) == len(return types of toy.func)`

For each `i`: `replaceAllUsesWith(replacements[i], operand(op, i))`,
i.e. `replaceAllUsesWith(%r, %result_c)`:

```
toy.print %r   →   toy.print %result_c
```

`%r` now has zero uses.

**Step 3 — cleanup**: erase the call op (`%r` unused) and the cloned
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

`materializeCallConversion` runs between steps 1 and 2 when the return type
and call-result type differ (ranked vs. unranked tensor): it inserts a
`toy.cast` so `handleTerminator` has a type-compatible value to substitute.

## Why `handleTerminator` Is Dialect-Specific

The inliner cannot provide a default because:

- The mapping from terminator operands to call results is dialect-defined.
  Positional for `toy.return`; different for `scf.yield`, `affine.yield`, etc.
- Non-exit blocks have a second overload, `handleTerminator(op, Block*)`, that
  redirects internal branches — the branch instruction is dialect-specific.
- When types mismatch, `handleTerminator` and `materializeCallConversion` work
  together; a default implementation cannot know the dialect's type algebra.

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
