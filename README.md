# CREST — Conversion and Rewriting Engine for Scheme Transformations

CREST is a homoiconic pattern DSL for MLIR — patterns are Scheme macros, so
constraints and rewrite logic are plain Scheme functions with no C++ escapes
and a seconds-level edit-reload cycle. Unlike [PDL](https://mlir.llvm.org/docs/PDLL/)
and [DRR](https://mlir.llvm.org/docs/DeclarativeRewrites/), CREST generates
both `RewritePattern` and `ConversionPattern` subclasses, covering dialect
conversion passes that neither DSL supports.

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

During development, `.sls` files are loaded from the filesystem at runtime —
edit a pattern and re-run, no rebuild needed.

In production, the deployed binary must be able to find the `.sls` files at
the same paths used at build time. If the deployment environment does not have
the source tree, the binary will fail at startup. `CREST_EMBED_SCHEME_BOOT=ON`
eliminates this dependency: all `.sls` libraries are compiled into a single
`crest.boot` file and embedded as a C byte-array in the binary. The deployed
binary requires no `.sls` files at runtime.

```bash
cmake -B build -DCREST_EMBED_SCHEME_BOOT=ON
cmake --build build   # compiles .sls → crest.boot → embeds in binary
```

Downstream projects include their own `.sls` files in the boot by setting
`CREST_BOOT_SOURCE_DIRS` (directories containing `.sls` files) and
`CREST_BOOT_ROOTS` (root entry points whose transitive imports are compiled)
before `add_subdirectory(crest)`. CREST compiles all roots and their
dependencies into a single `crest.boot` at build time.

```cmake
# In your project's CMakeLists.txt, before add_subdirectory(crest):
set(CREST_EMBED_SCHEME_BOOT ON)
list(PREPEND CREST_BOOT_SOURCE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/scheme")
list(PREPEND CREST_BOOT_ROOTS       "${CMAKE_CURRENT_SOURCE_DIR}/scheme/my-pass.sls")
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
