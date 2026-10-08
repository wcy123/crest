# CREST — Getting Started

## Quick start

After building (see [Prerequisites](#prerequisites) below):

```bash
# Run the test suite
CREST_PATH=$(pwd)/samples cmake --build build --target check-crest

# Run the sample hip-fusion pass on your own MLIR module
CREST_PATH=/path/to/crest/samples \
  build/tools/crest-opt/crest-opt \
  --crest-pass="module=passes/hip-fusion" \
  my-module.mlir
```

---

## Prerequisites

| Dependency | Version | Notes |
|---|---|---|
| LLVM / MLIR | 22 | See per-platform instructions below |
| Clang | 22 | C++17, `-fno-rtti` |
| CMake | ≥ 3.20 | Kitware PPA on Ubuntu 20.04 |
| Ninja | any | `sudo apt install ninja-build` |
| Python | ≥ 3.8 | for `lit` test runner |
| libncurses, uuid | any | Chez Scheme runtime deps |

```bash
pip install lit
```

---

## Ubuntu 22.04 (recommended)

```bash
# LLVM 22 + MLIR
wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key \
  | sudo tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc
echo "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-22 main" \
  | sudo tee /etc/apt/sources.list.d/llvm.list
sudo apt-get update
sudo apt-get install -y clang-22 llvm-22-dev libmlir-22-dev mlir-22-tools

# Build dependencies
sudo apt-get install -y build-essential ninja-build libncurses-dev uuid-dev
```

Build CREST:

```bash
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_C_COMPILER=clang-22 \
  -DCMAKE_CXX_COMPILER=clang++-22 \
  -DMLIR_DIR=/usr/lib/llvm-22/lib/cmake/mlir \
  -DLLVM_DIR=/usr/lib/llvm-22/lib/cmake/llvm
cmake --build build -j$(nproc)
```

---

## Ubuntu 20.04

The `apt.llvm.org` packages require `libc6 ≥ 2.34`, which is not available
on focal. Build LLVM 22 from source (~30 min, ~20 GB disk).

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

> `-DLLVM_INSTALL_UTILS=ON` is required — it installs `FileCheck` and exports
> it as a CMake target. Without it the test suite fails.

Build CREST:

```bash
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DMLIR_DIR=/usr/local/lib/cmake/mlir \
  -DLLVM_DIR=/usr/local/lib/cmake/llvm
cmake --build build -j$(nproc)
```

---

## Running tests

```bash
# Unit tests
./build/unittests/Interpreter/CrestInterpreterTests

# Integration tests (lit + FileCheck)
CREST_PATH=$(pwd)/samples cmake --build build --target check-crest
```

---

## CREST_PATH

`CREST_PATH` is a colon-separated list of directories where the interpreter
searches for `.sls` files at runtime, analogous to `PATH`:

```bash
export CREST_PATH=/my-project/scheme:/path/to/crest/samples
```

During development, edit a `.sls` file and re-run — no rebuild needed.

---

## Deployment

### Filesystem (default)

Deploy the binary alongside the `.sls` source tree. Set `CREST_PATH` at runtime:

```bash
export CREST_PATH=/my-project/scheme
build/tools/crest-opt/crest-opt --crest-pass="module=passes/my-pass" input.mlir
```

### Embedded boot (production)

Compile all `.sls` libraries into a single `crest.boot` file embedded in the
binary. The deployed binary requires no `.sls` files at runtime:

```bash
cmake -B build -DCREST_EMBED_SCHEME_BOOT=ON
cmake --build build
```

For downstream projects that add their own patterns:

```cmake
# In your CMakeLists.txt, before add_subdirectory(crest):
set(CREST_EMBED_SCHEME_BOOT ON)
list(PREPEND CREST_BOOT_SOURCE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/scheme")
list(PREPEND CREST_BOOT_ROOTS       "${CMAKE_CURRENT_SOURCE_DIR}/scheme/my-pass.sls")
add_subdirectory(crest)
```

---

## Extending with custom C++ bindings

Downstream projects register additional C++ bindings without modifying CREST:

```cpp
extern "C" void crest_register_extra_bindings(void (*fn)());

crest_register_extra_bindings([]() {
  Sregister_symbol("myDialect::MyOp::create", (void*)my_dialect_op_create);
});
```
