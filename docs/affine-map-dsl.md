<!--
Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
Licensed under the MIT License.
-->

**Date:** 2026-11-04
**Document Type:** Design
**Status:** Draft
**Related:** [manual.md](manual.md#context-parameters) (`current-MLIRContext`), [manual.md](manual.md#5-begin-mlir-code) (the other flat DSL), [architecture.md](architecture.md) (where bindings sit)

---

# `affine-map` DSL

## Overview

An `mlir::AffineMap` is built from `AffineExpr` values with C++ operators, or parsed from the
text `affine_map<(d0, d1)[s0] -> (d0 + s0, d1)>`. In Scheme the first is a list of binding calls
and the second is a string. `affine-map` is a macro that writes the same map as an expression,
so the structure can depend on Scheme values, and a wrong or misspelled name is reported when the
library compiles.

```scheme
(affine-map (d0 d1) (s0)        ; dimensions, symbols
  (+ d0 s0)                     ; result 0
  d1)                           ; result 1
```

## Contents

- [Syntax](#syntax)
- [Meaning of the names](#meaning-of-the-names)
- [Expansion](#expansion)
- [Operands](#operands)
- [Bindings it needs](#bindings-it-needs)
- [Errors](#errors)
- [Tests](#tests)
- [Decisions](#decisions)

---

## Design

### Syntax

```scheme
(affine-map (dim ...) (sym ...) result ...)
```

| Part | Meaning |
|---|---|
| `(dim ...)` | identifiers naming the dimensions, in order |
| `(sym ...)` | identifiers naming the symbols, in order |
| `result ...` | zero or more result expressions, in order |

Each result is an ordinary Scheme expression, evaluated where the names and operators below are
in scope. It yields an `AffineExpr` or an integer. An integer is taken as a constant.

The operators are `+`, `-`, `*`, `floordiv`, `ceildiv` and `mod`. `+` and `*` take two or more
operands and fold to the left. `-` with one operand is negation, and with two or more it
subtracts left to right. `floordiv`, `ceildiv` and `mod` take exactly two. The value of the whole
form is an `AffineMap`, as an opaque pointer like every other binding.

`affine-map` is defined in `(crest affine-map)` and exported by `(crest)`. The text form
`affine_map<(d0, d1)[s0] -> (d0 + s0, d1)>` is written
`(affine-map (d0 d1) (s0) (+ d0 s0) d1)`.

### Meaning of the names

A dimension or symbol has no name in the C++ API, only a position. The names in
`(dim ...)` and `(sym ...)` exist so the body can refer to a position: the name in position `i` of
the dimension list is `getAffineDimExpr(i)`, and the name in position `j` of the symbol list is
`getAffineSymbolExpr(j)`. The lengths of the two lists are the dimension and symbol counts of the
map, so `(affine-map (i j) ())` is `(d0, d1) -> ()` even though no result uses `j`. Any
identifiers work; `d` and `s` are only a convention inherited from MLIR's printer. Two maps
written with different names are the same map.

### Expansion

The body runs in a scope where the dimension and symbol names are `let`-bound (points 2 and 3 of
the design) and the operator names are rebound to the `AffineExpr` bindings (point 1):

```scheme
(affine-map (d0 d1) (s0) (+ d0 s0) d1)
;; expands to
(let ([d0 (mlir::getAffineDimExpr 0)]
      [d1 (mlir::getAffineDimExpr 1)]
      [s0 (mlir::getAffineSymbolExpr 0)]
      [+  mlir::AffineExpr::operator+]            ; likewise -, *, floordiv, ceildiv, mod
      ...)
  (mlir::AffineMap::get 2 1                       ; dimension count, symbol count
    (list (+ d0 s0)                               ; calls the AffineExpr operator
          d1)))
```

```
 (affine-map (d0 d1) (s0) (+ d0 s0) d1)
        |
        |  dims and symbols -> one let binding each, by position
        |  + - * ...        -> let-bound to the AffineExpr bindings
        |  lengths          -> dimension count 2, symbol count 1
        v
 let ([d0 dim 0] [d1 dim 1] [s0 sym 0] [+ ...])  AffineMap::get 2 1 (list expr0 expr1)
        |
        v
 affine_map<(d0, d1)[s0] -> (d0 + s0, d1)>
```

The operator names are introduced in the lexical context of the `affine-map` form, so a `+`
written by the caller inside the body is the affine operator, and outside the body nothing
changes. The body is plain Scheme, so any Scheme variable is visible in it:

```scheme
(affine-map (i) ()                  ; t is a Scheme integer in scope
  (floordiv i t)
  (mod i t))
```

The context is `(current-MLIRContext)`, as for the other constructors. To use another context,
wrap the form in `with-current-MLIRContext`.

### Operands

An operator accepts an `AffineExpr` or an integer for each operand. An integer becomes
`getAffineConstantExpr`. When every operand is an integer, the operator does ordinary integer
arithmetic and returns an integer, so `(* 2 t)` inside the body is just a number. A result that
is an integer is a constant. This is what lets a runtime value enter with no marking.

The operators can only do this if an `AffineExpr` and an integer can be told apart at run time.
A raw `AffineExpr` handle is an opaque pointer, which is a Scheme integer. So in the public
library an `AffineExpr` is a distinct Scheme value that holds the pointer. The raw `%` bindings
still return and take the pointer. The public bindings box the pointer on the way out, unbox it on
the way in, and add the predicate `mlir::AffineExpr?`. A value that is neither an integer nor an
`AffineExpr` raises a Scheme error naming the operator.

The `int64_t` overloads of the C++ operators are not bound, because MLIR defines `d0 + 1` as
`d0 + getAffineConstantExpr(1)`. `-` is not bound either. MLIR defines negation as
`e * getAffineConstantExpr(-1)` and `a - b` as `a + (-b)`, so the public `-` is built from `+` and
`*`.

### Bindings it needs

All follow the binding rules in CLAUDE.md: the C++ name is the Scheme name, raw `%` bindings in a
private library, an optional context where the C++ API takes one.

| C++ API | Used for |
|---|---|
| `mlir::getAffineDimExpr(unsigned, MLIRContext*)` | a dimension name |
| `mlir::getAffineSymbolExpr(unsigned, MLIRContext*)` | a symbol name |
| `mlir::getAffineConstantExpr(int64_t, MLIRContext*)` | a constant |
| `mlir::AffineExpr::operator+(AffineExpr)`, `operator*(AffineExpr)` | `+`, `*`, and `-` through them |
| `mlir::AffineExpr::floorDiv(AffineExpr)`, `ceilDiv(AffineExpr)`, `operator%(AffineExpr)` | `floordiv`, `ceildiv`, `mod` |
| `mlir::AffineMap::get(unsigned, unsigned, ArrayRef<AffineExpr>, MLIRContext*)` | the result; the only `get` overload bound |
| `mlir::AffineExpr?` (Scheme predicate, no C++ call) | tells an `AffineExpr` from an integer |

An `AffineExpr` and an `AffineMap` are context-owned: valid for the context's lifetime, never
freed by Scheme. An `AffineMap` is an opaque pointer. An `AffineExpr` is the boxed pointer above. The three leaf constructors need the context; the operators do
not, because it is inside their operands.

### Errors

| Mistake | Reported |
|---|---|
| a dimension or symbol name repeated, or the same in both lists | at expansion, at the name |
| a name that is an operator name | at expansion, at the name |
| an identifier bound nowhere | at expansion, as an unbound identifier with its line and column |
| wrong operand count (`(mod i)`, `(floordiv i 2 3)`) | at run time, as a procedure arity error |
| an operand that is neither an integer nor an `AffineExpr` | at run time, naming the operator |

MLIR accepts maps that are not pure affine, such as `d0 * d1`. The macro does not reject them,
and a later verifier may. `AffineExpr::isPureAffine` can check a result if needed.

### Tests

- Every operator, with expression and constant operands, compared with the text form through the
  printed map.
- A Scheme integer variable as an operand, integer-only arithmetic inside the body, and an
  `AffineExpr` variable built elsewhere.
- Dimensions only, symbols only, and zero results.
- Each error in the table above: the expansion errors as libraries that must fail to compile,
  the run-time ones as a call that must raise.
- One op that needs the map, an `affine.load` with its `map` attribute.

### Decisions

- **`AffineExpr` representation.** Boxed, as in [Operands](#operands). The alternative, raw
  pointers with an explicit `(constant 1)` for each constant, was not taken.
- **Overload naming.** One overload is bound per name. `mlir::AffineMap::get` is the general
  `(dims, symbols, results, ctx)` form, so CLAUDE.md Rule 4 needs no overload suffix. A map with no
  results is `(mlir::AffineMap::get 0 0 '())` or `(affine-map () ())`.

---

## Related Documents

- [manual.md](manual.md#5-begin-mlir-code) - `begin-mlir-code`, the other flat DSL, and how it passes attributes
- [manual.md](manual.md#context-parameters) - `current-MLIRContext` and `with-current-MLIRContext`
- [crest-object.md](crest-object.md) - why a handle crosses the FFI as an integer
