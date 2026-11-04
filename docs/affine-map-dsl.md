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
so the structure can depend on Scheme values and mistakes are reported when the library compiles.

```scheme
(affine-map (d0 d1) (s0)        ; dimensions, symbols
  (+ d0 s0)                     ; result 0
  d1)                           ; result 1
```

## Contents

- [Syntax](#syntax)
- [Meaning of the names](#meaning-of-the-names)
- [Expansion](#expansion)
- [Operands: expression or constant](#operands-expression-or-constant)
- [Bindings it needs](#bindings-it-needs)
- [Errors](#errors)
- [Tests](#tests)
- [Open questions](#open-questions)

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

A result expression is one of:

| Form | Value |
|---|---|
| a `dim` or `sym` name | that dimension or symbol |
| an integer literal | a constant |
| `,expr` | the Scheme integer `expr`, as a constant |
| `(op operand ...)` | the operator applied to its operands |

The operators are `+`, `-`, `*`, `floordiv`, `ceildiv` and `mod`. `+` and `*` take two or more
operands and fold to the left. `-` with one operand is negation, and with two or more it
subtracts left to right. `floordiv`, `ceildiv` and `mod` take exactly two. The value of the whole
form is an `AffineMap`, as an opaque pointer like every other binding.

The text form `affine_map<(d0, d1)[s0] -> (d0 + s0, d1)>` is written
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

The body runs in a scope where the names are bound and the operators mean the `AffineExpr`
operations (points 1 to 3 of the design):

```scheme
(affine-map (d0 d1) (s0) (+ d0 s0) d1)
;; expands to
(let ([d0 (mlir::getAffineDimExpr 0)]
      [d1 (mlir::getAffineDimExpr 1)]
      [s0 (mlir::getAffineSymbolExpr 0)])
  (mlir::AffineMap::get 2 1                       ; dimension count, symbol count
    (list (mlir::AffineExpr::operator+ d0 s0)     ; (+ d0 s0)
          d1)))
```

```
 (affine-map (d0 d1) (s0) (+ d0 s0) d1)
        |
        |  dims and symbols -> one let binding each, by position
        |  operators        -> AffineExpr bindings
        |  lengths          -> dimension count 2, symbol count 1
        v
 let ([d0 dim 0] [d1 dim 1] [s0 sym 0])  AffineMap::get 2 1 (list expr0 expr1)
        |
        v
 affine_map<(d0, d1)[s0] -> (d0 + s0, d1)>
```

The context is `(current-MLIRContext)`, as for the other constructors. To use another context,
wrap the form in `with-current-MLIRContext`.

### Operands: expression or constant

An `AffineExpr` and an integer are both Scheme integers: an `AffineExpr` crosses the FFI as an
opaque pointer. The two cannot be told apart at run time, and the C++ operators have a different
overload for each. So each operator classifies its operands **when the macro expands**:

| Operand | Treated as | Built with |
|---|---|---|
| integer literal, or `,expr` | constant | `getAffineConstantExpr` |
| anything else | an `AffineExpr` | used as is |

Every operator is then applied in its `AffineExpr` by `AffineExpr` form. The overloads that
take an `int64_t` are not bound, because MLIR defines `d0 + 1` as `d0 + getAffineConstantExpr(1)`.
`-` is not bound either. MLIR defines negation as `e * getAffineConstantExpr(-1)` and `a - b` as
`a + (-b)`, so the macro expands `(- e)` to `(* e -1)` and `(- a b)` to `(+ a (* b -1))`.

The operators are bound by the macro as syntax, introduced in the body's own lexical context, so
a `+` written in the body is the affine operator and not Scheme's. Outside the body nothing
changes. This is also how a runtime value enters:

```scheme
(affine-map (i) ()                  ; tile size t is a Scheme integer
  (floordiv i ,t)
  (mod i ,t))
```

An `AffineExpr` built elsewhere is used by naming the variable that holds it, with no `,`.
A Scheme variable that holds an integer must be written `,x`. Writing `x` treats the integer as
an expression pointer.

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
| `mlir::AffineMap::get(unsigned, unsigned, ArrayRef<AffineExpr>, MLIRContext*)` | the result |

An `AffineExpr` and an `AffineMap` are context-owned opaque pointers: valid for the context's
lifetime, never freed by Scheme. The three leaf constructors need the context; the operators do
not, because it is inside their operands.

### Errors

| Mistake | Reported |
|---|---|
| a dimension or symbol name repeated, or the same in both lists | at expansion, at the name |
| a name that is an operator keyword | at expansion, at the name |
| wrong operand count (`(mod i)`, `(floordiv i 2 3)`) | at expansion, at the operator |
| `-` or `+` with no operand | at expansion, at the operator |
| an identifier bound nowhere | at expansion, as an unbound identifier with its line and column |
| a non-integer `,expr` | at run time, in the constant constructor |

MLIR accepts maps that are not pure affine, such as `d0 * d1`. The macro does not reject them,
and a later verifier may. `AffineExpr::isPureAffine` can check a result if needed.

### Tests

- Every operator, with expression and constant operands, compared with the text form through the
  printed map.
- A `,expr` constant, and an `AffineExpr` variable used as an operand.
- Dimensions only, symbols only, and zero results.
- Each error in the table above, as a library that must fail to compile with the message.
- One op that needs the map, an `affine.load` with its `map` attribute.

### Open questions

- **Overload naming.** `mlir::AffineMap::get` is already bound as the context-only overload. The
  general overload needs a distinct raw symbol, and CLAUDE.md Rule 4 gives the full C++ qualified
  name but no rule for overloads. A suffix naming the argument kinds is one option. The rule should
  be decided and written into Rule 4 before the second `get` is bound.

---

## Related Documents

- [manual.md](manual.md#5-begin-mlir-code) - `begin-mlir-code`, the other flat DSL, and how it passes attributes
- [manual.md](manual.md#context-parameters) - `current-MLIRContext` and `with-current-MLIRContext`
- [crest-object.md](crest-object.md) - why a handle crosses the FFI as an integer
