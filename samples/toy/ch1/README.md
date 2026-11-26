# Toy Ch1 — The Language and its AST

Ch1 reads a Toy program and prints its AST. It has no MLIR in it: a lexer, a recursive-descent
parser and the AST types, all plain Scheme. Every later chapter builds on these three files.

## Try it

`example.toy` has a function, `multiply_transpose`, and a `main` that calls it:

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
}
```

Run the command in this directory. `./toyc` finds `scheme-mlir` through `CREST_BUILD_DIR` or `PATH`.

```sh
./toyc example.toy --emit=ast
```

```text
  Module:
    Function
      Proto 'multiply_transpose' @example.toy:0:1
      Params: [a, b]
      Block {
        Return
          BinOp: * @example.toy:1:23
            Call 'transpose' [ @example.toy:1:10
              var: a @example.toy:1:20
            ]
            Call 'transpose' [ @example.toy:1:25
              var: b @example.toy:1:35
            ]
      } // Block
    Function
      Proto 'main' @example.toy:4:1
      Params: []
      Block {
        VarDecl a<> @example.toy:5:3
          Literal: <2,3>[ <3>[ 1, 2, 3], <3>[ 4, 5, 6]] @example.toy:5:11
        VarDecl b<2,3> @example.toy:6:3
          Literal: <6>[ 1, 2, 3, 4, 5, 6] @example.toy:6:17
        VarDecl c<> @example.toy:7:3
          Call 'multiply_transpose' [ @example.toy:7:11
            var: a @example.toy:7:30
            var: b @example.toy:7:33
          ]
        VarDecl d<> @example.toy:8:3
          Call 'multiply_transpose' [ @example.toy:8:11
            var: b @example.toy:8:30
            var: a @example.toy:8:33
          ]
        VarDecl e<> @example.toy:9:3
          Call 'multiply_transpose' [ @example.toy:9:11
            var: c @example.toy:9:30
            var: d @example.toy:9:33
          ]
        VarDecl f<> @example.toy:10:3
          Call 'multiply_transpose' [ @example.toy:10:11
            var: a @example.toy:10:30
            var: c @example.toy:10:33
          ]
      } // Block
```

How to read it:

- `Module` holds the functions, in the order of the source. Each `Function` has a `Proto` (its name), its `Params`, and
  a `Block` with the statements.
- Many nodes (`Proto`, `VarDecl`, `Call`, `var`, `BinOp`, `Print`) end with where they are in the file,
  `@example.toy:4:1` for `line:column`. The first line is line 0.
- `VarDecl a<>` has no declared shape, and `VarDecl b<2,3>` declares one. A `Literal` carries its shape too:
  `<2,3>[ <3>[ 1, 2, 3], <3>[ 4, 5, 6]]` is a `2x3` literal, and `<6>[ 1, 2, 3, 4, 5, 6]` is a flat one.
- `Call 'multiply_transpose' [ ... ]` lists the arguments of a call, `BinOp: *` has its two operands, and `Return`
  has its value.
- Nothing is typed or computed here. Turning this tree into MLIR starts in [Ch2](../ch2/README.md).

## Files

| File | What it does |
|---|---|
| `lexer.sls` | tokens: identifiers, numbers, punctuation, with line and column |
| `parser.sls` | recursive-descent parser producing the AST, and the AST dump |
| `ast.sls` | AST records: functions, prototypes, expressions, source locations |
| `toyc.sls` | the driver: reads the file and runs the one action, `--emit=ast`. `(rime command-line-options)` reads the command line, so the options and the file come in any order and `-h` shows the usage |

## What is written with the DSL

Nothing here uses CREST: there is no MLIR yet. The DSL starts in
[Ch2](../ch2/README.md), where the program is turned into IR.
