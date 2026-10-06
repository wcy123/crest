# CREST — Conversion and Rewriting Engine for Scheme Transformations

CREST is a homoiconic pattern DSL for MLIR — patterns are Scheme macros, so
constraints and rewrite logic are plain Scheme functions with no C++ escapes
and a seconds-level edit-reload cycle. Unlike [PDL](https://mlir.llvm.org/docs/PDLL/)
and [DRR](https://mlir.llvm.org/docs/DeclarativeRewrites/), CREST generates
both `RewritePattern` and `ConversionPattern` subclasses, covering dialect
conversion passes that neither DSL supports.

See [docs/architecture.md](docs/architecture.md) for a full design overview.

## Setup

### Ubuntu 22.04 (recommended, matches CI)

```bash
# LLVM 22 + MLIR
wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key \
  | sudo tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc
echo "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-22 main" \
  | sudo tee /etc/apt/sources.list.d/llvm.list
sudo apt-get update
sudo apt-get install -y clang-22 llvm-22-dev libmlir-22-dev mlir-22-tools

# Other build dependencies
sudo apt-get install -y \
  build-essential ninja-build \
  libncurses-dev uuid-dev \
  libgtest-dev googletest
pip install lit

# Build CREST
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_C_COMPILER=clang-22 \
  -DCMAKE_CXX_COMPILER=clang++-22 \
  -DMLIR_DIR=/usr/lib/llvm-22/lib/cmake/mlir \
  -DLLVM_DIR=/usr/lib/llvm-22/lib/cmake/llvm
cmake --build build -j$(nproc)
```

### Ubuntu 20.04

The `apt.llvm.org` packages require `libc6 ≥ 2.34`, which is not available
on focal. Build LLVM 22 from source instead (~30 min, ~20 GB disk):

`pip install cmake` does not work for building LLVM — it loses `CMAKE_ROOT`.
Use the Kitware PPA:
```bash
wget -qO- https://apt.kitware.com/keys/kitware-archive-latest.asc \
  | sudo apt-key add -
sudo apt-add-repository 'deb https://apt.kitware.com/ubuntu/ focal main'
sudo apt-get update && sudo apt-get install cmake
```

Build and install LLVM:
```bash
git clone --depth=1 --branch llvmorg-22.1.8 https://github.com/llvm/llvm-project.git
cmake -B llvm-project/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="mlir" \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DLLVM_INSTALL_UTILS=ON \
  llvm-project/llvm
cmake --build llvm-project/build -j$(nproc)
sudo cmake --install llvm-project/build --prefix /usr/local
```

`-DLLVM_INSTALL_UTILS=ON` is required — it installs `FileCheck` and exports
it as a CMake target. Without it the test suite fails.

Then build CREST:
```bash
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DMLIR_DIR=/usr/local/lib/cmake/mlir \
  -DLLVM_DIR=/usr/local/lib/cmake/llvm
cmake --build build -j$(nproc)
```

## Quick start

After setup, run tests:
```bash
# Unit tests
./build/unittests/Interpreter/CrestInterpreterTests

# Integration tests (lit + FileCheck)
CREST_PATH=$(pwd)/samples cmake --build build --target check-crest
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
  :if-match
      %cast = onnx.Cast (%data)
                :where (quantized-tensor? %data)
  :rewrite %cast :with
      (%result = hipsr.cast (%data) -> (mlir-value-get-type %cast)))
```

The match side names operands structurally. The `:where` guard is plain
Scheme — any predicate, no C++ required. `:rewrite %cast :with` names the
root op to replace and lists the builder calls; CREST emits the
`replaceOp` call automatically.

A pass entry point:

```scheme
(library (passes my-pass)
  (export run-pass)
  (import (rnrs) (crest)
          (mlir IR MLIRContext)
          (mlir IR Operation)
          (mlir Transforms DialectConversion))

  (define (run-pass module-op)
    (with-mlir-context (mlir::Operation::getContext module-op)
      (with-type-converter (tc)
        (with-conversion-target (target (current-mlir-context))
          (with-pattern-set (patterns (current-mlir-context))
            (mlir::applyFullConversion module-op target patterns)))))))
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
edit a pattern and re-run, no rebuild needed. Downstream developers point
`CREST_PATH` at their own `.sls` directory; the interpreter picks up changes
on the next run without touching the CREST build:

```bash
export CREST_PATH=/my-project/scheme
build/tools/crest-opt/crest-opt --crest-pass="module=passes/my-pass" input.mlir
```

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
  Sregister_symbol("myDialect::MyOp::create", (void*)my_dialect_op_create);
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
