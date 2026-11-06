# Toy Ch7 — Structs

Ch7 adds user-defined struct types to the Toy language: a `struct` declaration,
struct-typed function parameters and variables, struct literals, and `.` field
access. In the dialect these become a struct type plus two new ops,
`toy.struct_constant` and `toy.struct_access`, which the pipeline folds away
before lowering. The lowering to Affine and LLVM is unchanged from Ch6.

## What's new over Ch6

| Feature | Ch6 | Ch7 |
|---|---|---|
| Language | `def`, `var`, calls, `print` | + `struct`, struct-typed params/vars, `{...}` literals, `a.b` |
| Lexer | — | `struct` keyword; `.` is punctuation unless followed by a digit |
| AST | functions only | + `struct-ast`, `struct-literal-expr`, `module-ast:structs` |
| Dialect | tensor ops | + struct type, `toy.struct_constant`, `toy.struct_access` |
| Canonicalization | 4 patterns | + `FoldStructAccessOfConstant` |
| Pipeline | inline, shape inference, canonicalize | + struct fold and dead `struct_constant` erase before shape inference |
| Lowering | Affine, LLVM | unchanged (`lower-to-affine.sls`, `lower-to-llvm.sls` differ only in library name) |

## Language

```
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

This program is `test/toy/ch7/example.toy`. The `example.toy` next to this
README is the Ch6 tensor program and does not use structs.

- A struct is declared with `struct Name { var field; ... }`. Fields have no
  initializer and no type annotation.
- A parameter or variable of struct type is written `Name ident`, e.g.
  `Struct value = {...}`.
- A struct literal is `{ expr, expr, ... }` and may nest.
- `value.a` selects a field by name.

## Dialect additions (`toy.sls`)

| Op / type | Meaning |
|---|---|
| `toy.struct_constant` | Constant struct. Attribute `value` is an `ArrayAttr` of `DenseElementsAttr` (or nested `ArrayAttr` for nested structs); the result is a struct type. |
| `toy.struct_access` | `%s[N]`: field `N` of a struct value. Attribute `index` (`i64`). |
| `toy::StructType` | Defined in `(mlir Dialect Toy ToyStructType)` |

`toy::StructType` is implemented on top of `mlir::TupleType`; it is not a
separate type with its own storage. Structs therefore print as
`tuple<tensor<2x3xf64>, tensor<2x3xf64>>`, and `toy::StructType?` is true for
any tuple.

The dialect's `:materialize-constant` hook returns `toy.struct_constant` for
struct types and `toy.constant` otherwise, so constant folding can produce
either.

Raw MLIR for the example (`--emit=mlir`):

```mlir
toy.func private @multiply_transpose(%arg0: tuple<tensor<*xf64>, tensor<*xf64>>) {
  %0 = "toy.struct_access"(%arg0) {index = 1 : i64} : (tuple<tensor<*xf64>, tensor<*xf64>>) -> tensor<*xf64>
  ...
}
toy.func @main() {
  %0 = "toy.struct_constant"() {value = [dense<...> : tensor<2x3xf64>, dense<...> : tensor<2x3xf64>]} : () -> tuple<tensor<2x3xf64>, tensor<2x3xf64>>
  %1 = toy.generic_call @multiply_transpose(%0) : (tuple<tensor<2x3xf64>, tensor<2x3xf64>>) -> tensor<*xf64>
  ...
}
```

## Front end

- **`lexer.sls`** — new `tok-struct`. A `.` is returned as its own token unless
  a digit follows, so `value.a` is not lexed as a number.
- **`parser.sls`** — `parseStruct ::= 'struct' identifier '{' var-decl+ '}'`;
  `parseModule` accepts structs and functions in any order; struct literals are
  parsed by `%%parse-struct-literal`; `Name ident = expr` declares a struct-typed
  variable.
- **`ast.sls`** — `struct-ast`, `struct-literal-expr`, and
  `module-ast:structs`; `--emit=ast` dumps struct declarations.
- **`mlir-gen.sls`** — threads a `struct-map` (name to type and declaration)
  through generation. A struct literal becomes `toy.struct_constant`; `a.b`
  becomes `toy.struct_access` with the field index looked up from the
  declaration; struct-typed parameters get the struct type instead of an
  unranked tensor.

## Canonicalization (`combine.sls`)

Ch7 registers a fifth pattern alongside the four from Ch3:

| Pattern | Rewrite |
|---|---|
| `FoldStructAccessOfConstant` | `toy.struct_access(toy.struct_constant{[v0, v1, ...]}, N)` becomes `toy.constant{vN}` |

## `--opt` pipeline (`toyc.sls`)

There is no lowering for the struct ops, and the `toy` dialect is illegal in the
LLVM conversion, so they must be gone by the time lowering starts. The struct
fold is therefore part of the pipeline that every lowering action runs:

1. **Inline** — Scheme-level `%%inline-calls!`; `index` is among the
   attributes copied onto cloned ops so `toy.struct_access` survives inlining
2. **Fold structs** — greedy canonicalize so `struct_access(struct_constant)`
   folds to `toy.constant`, then erase any `toy.struct_constant` left without
   uses
3. **Shape inference** — as in Ch5/Ch6
4. **Canonicalize** — greedy rewrite again
5. Affine lowering, then LLVM lowering, then cleanup — as in Ch6

For the example, `--emit=mlir --opt` leaves `@main` with only tensor ops and
`multiply_transpose` inlined and removed:

```mlir
toy.func @main() {
  %0 = toy.constant dense<...> : tensor<2x3xf64>
  %1 = toy.transpose(%0 : tensor<2x3xf64>) to tensor<3x2xf64>
  %2 = toy.constant dense<...> : tensor<2x3xf64>
  %3 = toy.transpose(%2 : tensor<2x3xf64>) to tensor<3x2xf64>
  %4 = toy.mul %3, %1 : tensor<3x2xf64>
  toy.print %4 : tensor<3x2xf64>
  toy.return
}
```

## Known limitation

Field names are resolved to indices by looking up the struct declaration that
matches the value's *type*. Because a struct type is just a tuple of its field
types, two structs with the same layout cannot be told apart, and the first
declaration found wins. For example, with `struct A { var x; var y; }` declared
before `struct B { var p; var q; }`, accessing `v.q` on a `B` value fails with
`field not found in struct`.

## Commands

```sh
# Dump the AST (includes struct declarations)
./toyc example.toy --emit=ast

# Raw Toy MLIR (struct ops still present)
./toyc ../../../test/toy/ch7/example.toy --emit=mlir

# Structs folded away, inlined, shape-inferred, canonicalized
./toyc ../../../test/toy/ch7/example.toy --emit=mlir --opt

# Lowered to Affine, then to the LLVM dialect, then to LLVM IR
./toyc ../../../test/toy/ch7/example.toy --emit=mlir-affine --opt
./toyc ../../../test/toy/ch7/example.toy --emit=mlir-llvm --opt
./toyc ../../../test/toy/ch7/example.toy --emit=llvm --opt

# Compile and run
./toyc ../../../test/toy/ch7/example.toy --emit=jit --opt
```

Running the struct example with `--emit=jit` prints:

```
1.000000 16.000000
4.000000 25.000000
9.000000 36.000000
```

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect, with struct types and ops | `define-dialect` | the type and `toy.struct_constant`, `toy.struct_access` are declared in it |
| The `:materialize-constant` callback | `begin-mlir-code` with `with-current-OpBuilder` | it returns the op, not its result |
| Every op `mlir-gen.sls` creates, including the struct ops | `begin-mlir-code` | as in Ch2 |
| The canonicalization patterns, including `fold-struct-access` | `define-rewrite-pattern` | as in Ch3 |
| The lowerings and their registration | as in Ch5 and Ch6 | `apply-conversion`, `define-conversion-pattern`, `begin-mlir-code` |
| Shape inference | `define-rewrite-pattern`, as in Ch4 | |
| Inlining | Scheme, as in Ch4 | the reasons are in the Ch4 README; the inliner also copies the attributes `toy.struct_access` needs |

## Related Documents

- [../ch6/README.md](../ch6/README.md) — Ch6 LLVM lowering and `toy.print` → `printf`
- [../ch3/README.md](../ch3/README.md) — Ch3 canonicalization patterns
- [../ch4/inlining.md](../ch4/inlining.md) — how inlining works
