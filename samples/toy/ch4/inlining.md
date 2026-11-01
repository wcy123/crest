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

Given a call site:

```
%r = toy.generic_call @multiply_transpose(%A, %B)
toy.print %r
```

and callee:

```
toy.func @multiply_transpose(%a, %b) {
  %t0     = toy.transpose(%a)
  %t1     = toy.transpose(%b)
  %result = toy.mul %t0, %t1
  toy.return %result
}
```

The inliner performs five steps:

1. **Copy** — clone the callee's body (including the terminator) into the
   caller immediately after the call op, substituting call arguments for
   block arguments (`%a → %A`, `%b → %B`). Cloned ops produce fresh SSA
   values (`%result_c`, etc.).

2. **Dangling** — the call op still exists; `%r` is still defined by it and
   still consumed by `toy.print`. But the call op is about to be erased, so
   `%r`'s definition will disappear while its uses remain — a pending SSA
   violation.

3. **`handleTerminator`** — the inliner calls this callback with the cloned
   `toy.return` op and the list of dangling call results (`[%r]`).  The
   callback zips return operands with call results and calls
   `replaceAllUsesWith` for each pair:

   ```scheme
   (loop :for i    :from 0 :below n-replacements
         :for repl :in replacements
         :do (mlir::Value::replaceAllUsesWith
              repl                                  ; %r
              (mlir::Operation::getOperand op i)))  ; %result_c
   ```

   After this, `toy.print %r` becomes `toy.print %result_c` and `%r` has
   zero uses.

4. **`materializeCallConversion`** — if the return type and call-result type
   differ (ranked vs. unranked tensor), the inliner calls this callback to
   insert a `toy.cast` op bridging the mismatch. Shape inference resolves the
   cast later.

5. **Cleanup** — the inliner erases the call op (safe: `%r` has no uses) and
   the cloned `toy.return` (safe: `handleTerminator` consumed it).

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
