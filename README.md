# CREST — Conversion and Rewriting Engine for Scheme Transformations

CREST provides [Chez Scheme](https://cisco.github.io/ChezScheme/) bindings to
the [MLIR C API](https://mlir.llvm.org/docs/CAPI/), allowing MLIR conversion
and rewrite patterns to be written in Scheme rather than C++.

## Why

Writing MLIR dialect conversion passes in C++ requires implementing
`OpConversionPattern` subclasses, wiring `TypeConverter` and
`ConversionTarget`, and rebuilding the compiler for every pattern change.
MLIR's established pattern DSLs (PDL, DRR) only generate `RewritePattern`
subclasses — neither supports `ConversionPattern`.

CREST's pattern DSL generates `ConversionPattern` subclasses and uses Chez
Scheme as its extension language. Changing a pattern and reloading takes
seconds with no rebuild.

See [docs/architecture.md](docs/architecture.md) for a full design overview.

## Quick start

**Prerequisites:** CMake ≥ 3.20, Ninja, Python 3, LLVM/MLIR dev package.

```bash
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DMLIR_DIR=/path/to/mlir/lib/cmake/mlir \
  -DLLVM_DIR=/path/to/llvm/lib/cmake/llvm
cmake --build build
```

Run the sample hip-fusion pass:

```bash
CREST_PATH=/path/to/crest/samples \
  build/tools/crest-opt/crest-opt \
  --crest-pass="module=passes/hip-fusion" \
  my-module.mlir
```

## Writing a pattern

A conversion pattern in Scheme:

```scheme
(define-conversion-pattern (lower-cast op operands-ref rw tc)
  %cast = "onnx.Cast" (%data)
  :where (quantized-tensor? %data)
  :rewrite
    (%out = "hipsr.cast" (%data) -> (mlir-value-get-type %cast))
    (mlir-replace-op rw op %out)
  #t)
```

The match side names operands structurally. The `:where` guard is plain
Scheme — any predicate, no C++ required. The `:rewrite` body builds new ops
and returns `#t` on success.

A pass entry point:

```scheme
(library (passes my-pass)
  (export run-pass)
  (import (rnrs) (crest) (mlir core ir) (mlir core conversion))

  (define (run-pass module-op)
    (let* ([ctx     (mlir-operation-get-context module-op)]
           [tc      (mlir-create-type-converter)]
           [target  (mlir-create-conversion-target ctx)]
           [patterns (mlir-create-rewrite-pattern-set ctx)])
      (mlir-register-conversion-pattern patterns "onnx.Cast" lower-cast tc 1)
      (mlir-apply-full-conversion module-op target patterns))))
```

## CREST_PATH

`CREST_PATH` is a colon-separated (POSIX) or semicolon-separated (Windows)
list of directories where the interpreter searches for `.sls` files at
runtime, analogous to `PATH`. Point it at any directory containing your pass
libraries:

```bash
export CREST_PATH=/my-project/scheme:/path/to/crest/samples
```

## Deployment

By default, `.sls` files are loaded from the filesystem at runtime.  For
single-binary deployment with no `.sls` files required:

```bash
cmake -B build -DCREST_EMBED_SCHEME_BOOT=ON
cmake --build build   # compiles all .sls into crest.boot, embeds in binary
```

Downstream projects can add their own libraries to the boot:

```cmake
list(PREPEND CREST_BOOT_SOURCE_DIRS "${MY_SCHEME_DIR}")
list(PREPEND CREST_BOOT_ROOTS       "${MY_SCHEME_DIR}/my-pass.sls")
add_subdirectory(crest)
```

## Extending CREST

Downstream projects register additional C++ bindings without modifying CREST:

```cpp
extern "C" void crest_register_extra_bindings(void (*fn)());

// In your initialization:
crest_register_extra_bindings([]() {
  Sregister_symbol("my_dialect_op", (void*)my_dialect_op);
});
```

## Architecture

```
samples/passes/      — example passes (hip-fusion, onnx-to-hipsr)
scheme/              — core Scheme libraries (mlir core/dialects/support)
lib/Interpreter/     — Chez Scheme runtime wrapper
lib/Bindings/        — MLIR C API → Scheme FFI
lib/Passes/          — --crest-pass pipeline registration
tools/crest-opt/     — mlir-opt-style driver
```

See [docs/architecture.md](docs/architecture.md) for the full design.

## License

MIT — see [LICENSE](LICENSE).
