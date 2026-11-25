# Toy Ch2 — The Toy Dialect and MLIR Generation

Ch2 defines the `toy` dialect in Scheme and turns the AST into MLIR, printed in the custom form of the
C++ tutorial (`toy.func @main() { ... }`). The dialect declares `toy.return` as a terminator
(`:traits (terminator)`), which needs LLVM 23.

```sh
# From the repository root
./samples/toy/ch2/toyc samples/toy/ch2/example.toy --emit=ast
./samples/toy/ch2/toyc samples/toy/ch2/example.toy --emit=mlir
```

## Files

| File | What it does |
|---|---|
| `toy.sls` | the `toy` dialect: `define-dialect` with its ops (`constant`, `add`, `mul`, `transpose`, `reshape`, `generic_call`, `func`, `return`, `print`) |
| `mlir-gen.sls` | walks the AST and creates the ops |
| `lexer.sls`, `parser.sls`, `ast.sls` | as in Ch1 |
| `toyc.sls` | the driver: `--emit=ast` or `--emit=mlir`. `(rime command-line-options)` reads the command line, so the options and the file come in any order and `-h` shows the usage |

## What is written with the DSL

| Part | Written with | Why |
|---|---|---|
| The dialect and its ops | `define-dialect` and `define-op` | the whole dialect is one declaration; the callbacks inside it are Scheme |
| The text form of `toy.print`, `toy.transpose`, `toy.reshape`, `toy.generic_call` and `toy.return` | `:assembly-format` | the same strings as the `assemblyFormat` of the C++ `Ops.td`; `toy.constant`, `toy.add`, `toy.mul` and `toy.func` have a hand-written `:parse` and `:print`, as in C++ (`hasCustomAssemblyFormat`) |
| Every op `mlir-gen.sls` creates | `begin-mlir-code`, with `:loc` carrying the Toy source location | one op-form per op; no `OperationState`, no explicit builder |
| The result types of `toy.constant`, `toy.add`, `toy.mul` and `toy.transpose` | `:interfaces ((mlir::InferTypeOpInterface ...))` | C++ gives these ops builders that work out the result type (`ConstantOp` takes the type of its value, the others an unranked `f64` tensor), so `MLIRGen.cpp` names none. Here the op infers it through `InferTypeOpInterface`, so `mlir-gen.sls` writes no `-> type` for them. `toy.reshape`, `toy.generic_call` and `toy.struct_constant` take an explicit type in C++ and here |
| The module that holds the functions | `mlir::ModuleOp::create` | it is the container, not an op the DSL builds |
| Lexer, parser, AST, driver | plain Scheme | not MLIR |

`test/toy/infer-result-types.mlir` keeps the result types honest in the same way: it fails if an op-form in
`mlir-gen.sls` writes a `-> type` for an op that infers it.

`test/toy/dsl-coverage.mlir` keeps this honest: it fails if a Toy tutorial creates an op with an
`OperationState` or a typed builder without being listed as an exception.

## Inspecting macro expansions

`tools/debug-define-dialect` pretty-prints what `define-dialect` expands to.
It is useful for understanding what the DSL generates and for debugging macro
issues.

```sh
# From the repository root — expand define-dialect in toy.sls
# (CREST_BUILD_DIR says where crest-opt is, or crest-opt is on PATH)
tools/debug-define-dialect samples/toy/ch2/toy.sls

# Save to a file
tools/debug-define-dialect samples/toy/ch2/toy.sls > /tmp/toy2.sls
```

### Key structures in the expanded output

`define-dialect toy` expands to a `begin` containing:

**`%%toy.func:interfaces`** — the pairs of the `:interfaces` entries of `toy.func`, made once when the library is
loaded. `mlir::SymbolOpInterface`, `mlir::ArgAndResultAttrsOpInterface`, `mlir::CallableOpInterface` and
`mlir::FunctionOpInterface` are macros of `(mlir IR SymbolInterfaces)`, `(mlir Interfaces CallInterfaces)` and
`(mlir Interfaces FunctionInterfaces)`: each makes a C function (a `foreign-callable`) for each method and answers the
pair of the interface's `TypeID` and a dispatcher of them. MLIR has no default for the methods of
`CallableOpInterface` and `FunctionOpInterface`, as in C++ the op class gives them, so `toy.func` gives them as
clauses; for `SymbolOpInterface` MLIR has one for each method (the `sym_name` attribute and the others), and
`(mlir::ArgAndResultAttrsOpInterface :standard)` keeps the `arg_attrs` and `res_attrs` attributes:

```scheme
(define %%toy.func:interfaces
  (list (mlir::SymbolOpInterface)
        (mlir::ArgAndResultAttrsOpInterface :standard)
        (mlir::CallableOpInterface
         (getCallableRegion (self) (mlir::Operation::getRegion self 0))
         (getArgumentTypes (self)
           (mlir::FunctionType::getInputs
            (mlir::TypeAttr::getValue
             (mlir::Operation::getAttr self "function_type"))))
         (getResultTypes (self)
           (mlir::FunctionType::getResults
            (mlir::TypeAttr::getValue
             (mlir::Operation::getAttr self "function_type")))))
        (mlir::FunctionOpInterface
         (getFunctionType (self)
           (mlir::TypeAttr::getValue
            (mlir::Operation::getAttr self "function_type")))
         (setFunctionTypeAttr (self attr)
           (mlir::Operation::setAttr! self "function_type" attr)))))
```

**`%%toy:initialize`** — called at dialect registration time; registers every
op via `%crest::register-dynamic-op!`, which installs the interfaces of the op in its definition:

```scheme
(define (%%toy:initialize dialect-ptr)
  (%crest::register-dynamic-op! dialect-ptr "toy.constant" ...)
  ...
  (%crest::register-dynamic-op! dialect-ptr "toy.func"
                                %%toy.func:op-callbacks %%toy.func:interfaces)
  ...)
```

**`toy`** — the dialect descriptor passed to CREST's dialect registry: `%%toy:initialize`, `#f` in the slots that
Toy does not use, and the interfaces of the dialect (none here):

```scheme
(define toy
  (crest-dialect-callback-entries %%toy:initialize #f #f #f #f
    #f #f #f #f #f #f %%toy:interfaces))
```

**`%%toy.constant:op-callbacks`** — for each op, the callbacks that Scheme makes for MLIR
(`crest-op-callback-entries`), the first being the verifier: it checks the number and the types of the results and
reports a failure with the position of the definition of the op in `toy.sls`.

**Accessor predicates and field getters** — one `?` predicate and one getter
per operand/attribute/result for every op, e.g.:

```scheme
(define (toy.constant? op)
  (string=? (mlir::Operation::getName op) "toy.constant"))
(define (toy.constant:value op) (mlir::Operation::getAttr op "value"))
(define (toy.constant:output op) (mlir::Operation::getResult op 0))
```
