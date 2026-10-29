# Tech Notes

## MLIR: Dialect Registration Must Happen Before Parsing

### The Constraint

You cannot register a dialect after the MLIR input has been parsed, if that dialect's ops appear in the input IR. This is a hard MLIR constraint.

From the [MLIR FAQ](https://mlir.llvm.org/getting_started/Faq/):

> The process of loading a dialect in the context is not thread-safe, which forces all involved dialects to be loaded **before** the multi-threaded pass manager starts execution.

From the [mlir::DialectRegistry reference](https://mlir.llvm.org/doxygen/classmlir_1_1DialectRegistry.html):

> The `MLIRContext::appendDialectRegistry` function contains an assertion: `impl->multiThreadedExecutionContext == 0`, meaning appending to the MLIRContext dialect registry is not allowed while in a multi-threaded execution context.

### Why: the `UnregisteredOpModel` use-after-free

#### Step 1 — How MLIR stores op names

Every `Operation` object holds an `OperationName`, which is a thin wrapper around a **raw pointer** (`OperationName::Impl*`). That `Impl` owns the op's full name string, its dialect pointer, and all registered behaviors. The `Operation` holds just the raw pointer — it does NOT own the `Impl`.

All `Impl` objects are owned by `MLIRContextImpl::operations` — a `StringMap<std::unique_ptr<Impl>>`. The `Operation` therefore has a raw pointer into memory managed by the context.

#### Step 2 — What "parsed before registration" means

`performActions` in `MlirOptMain` does:

```
parseSourceFile(input)   ← parsing
...
pm.run(op)               ← PassManager (getDependentDialects + passes)
```

Parsing happens **first**. When the parser sees `"ifacetest.func"` in the input file and the `ifacetest` dialect is not yet registered, it creates a temporary [`UnregisteredOpModel`](https://mlir.llvm.org/doxygen/structmlir_1_1OperationName_1_1UnregisteredOpModel.html) and stores it in `ctxImpl.operations["ifacetest.func"]`. The parsed `Operation` gets a raw pointer to that `UnregisteredOpModel`.

#### Step 3 — What registration does

Later, `getDependentDialects` (or an explicit `register!` call) invokes `RegisteredOperationName::insert`, which does:

```cpp
ctxImpl.operations[name] = std::move(ownedImpl);  // unique_ptr — OLD ENTRY IS FREED
```

Because `operations` is a `StringMap<std::unique_ptr<Impl>>`, assigning a new `unique_ptr` destroys the old one. The old `UnregisteredOpModel` is **freed (deleted)**.

#### Step 4 — The dangling pointer

The parsed `Operation` still holds its raw `OperationName::Impl*` — which now points to freed memory. Nobody told the `Operation` about the replacement.

When a pass later calls something like `mlir::FunctionOpInterface::getFunctionType func-op`, the C++ binding does:

```cpp
auto name_str = op->getName().getStringRef().str();
```

`op->name.impl_` is the freed pointer. Reading through it returns garbage. In CREST's case, this produced a `StringRef` with a nonsense length of ~500 TB, causing LLVM's allocator to report out-of-memory.

#### Why the old `exit/enter` hack "worked"

With `ifacetest:register!` called from inside `run-pass`, the same use-after-free existed. The old `UnregisteredOpModel` was freed and replaced by the newly registered `Impl`. The `Operation` still held the dangling pointer. But `delete` on a small object does not zero or immediately reuse the memory — the freed bytes still contain the old string data. The old approach "worked" by luck: the freed memory happened not to be reused before the next read. With a different allocation sequence (our new code), the freed memory was reused with different content, exposing the crash.

From the [MLIRContext.cpp source](https://mlir.llvm.org/doxygen/MLIRContext_8cpp_source.html):

> A critical issue was identified involving an `UnregisteredOpModel` use-after-free: calling `getOrLoadDialect` frees `UnregisteredOpModel` objects that `Operation::name` pointers still reference.

### The correct pattern

Passes declare dependent dialects via `getDependentDialects(DialectRegistry&)`. MLIR's `PassManager::run()` calls `getDependentDialects` and eagerly loads all declared dialects **before** `enterMultiThreadedExecution()`.

Call tree from `pm.run()` down to each individual pass's `getDependentDialects`:

```
PassManager::run()                                         Pass.cpp:1035
  getDependentDialects(dependentDialects)                  Pass.cpp:1054  ← dispatches to OpPassManager
  context->appendDialectRegistry(dependentDialects)        Pass.cpp:1055
  context->getOrLoadDialect(name)  [for each dialect]      Pass.cpp:1058  ← loads them now
  context->enterMultiThreadedExecution()                   Pass.cpp:1068  ← multi-threaded begins
  initialize(context, ...)                                 Pass.cpp:1077

OpPassManager::getDependentDialects(dialects)              Pass.cpp:474
  registerDialectsForPipeline(*this, dialects)             Pass.cpp:475

registerDialectsForPipeline(pm, dialects)                  Pass.cpp:468
  for pass in pm.getPasses():
    pass.getDependentDialects(dialects)                    Pass.cpp:471  ← calls each Pass subclass

  // If the pass is an adaptor wrapping nested managers:
  OpToOpPassAdaptor::getDependentDialects(dialects)        Pass.cpp:749
    pm.getDependentDialects(dialects)  [for each nested]   Pass.cpp:751  ← recurses into nested PMs

  // For a leaf pass (e.g. CrestPass):
  CrestPass::getDependentDialects(registry)                CrestPass.cpp  ← our override
```

Permalinks (commit `ca7933e`):
- [`PassManager::run` — Pass.cpp:1035](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Pass/Pass.cpp#L1035)
- [`getDependentDialects(dependentDialects)` — Pass.cpp:1054](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Pass/Pass.cpp#L1054)
- [`appendDialectRegistry` — Pass.cpp:1055](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Pass/Pass.cpp#L1055)
- [`getOrLoadDialect` loop — Pass.cpp:1058](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Pass/Pass.cpp#L1058)
- [`enterMultiThreadedExecution` — Pass.cpp:1068](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Pass/Pass.cpp#L1068)
- [`OpPassManager::getDependentDialects` — Pass.cpp:474](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Pass/Pass.cpp#L474)
- [`registerDialectsForPipeline` — Pass.cpp:468](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Pass/Pass.cpp#L468)
- [`pass.getDependentDialects` — Pass.cpp:471](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Pass/Pass.cpp#L471)
- [`OpToOpPassAdaptor::getDependentDialects` — Pass.cpp:749](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Pass/Pass.cpp#L749)

### Critical: `getDependentDialects` runs AFTER parsing

A common misconception: `getDependentDialects` runs before pass execution, so it might seem like it runs before parsing too. It does not. In `MlirOptMain::performActions`:

```
parseSourceFileForTool(...)    ← parsing FIRST
setupPassPipeline(pm)          ← configure PM
pm.run(*op)                    ← getDependentDialects runs INSIDE HERE
```

- [`parseSourceFileForTool` — MlirOptMain.cpp:521](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Tools/mlir-opt/MlirOptMain.cpp#L521)
- [`setupPassPipeline` — MlirOptMain.cpp:587](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Tools/mlir-opt/MlirOptMain.cpp#L587)
- [`pm.run` — MlirOptMain.cpp:591](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/Tools/mlir-opt/MlirOptMain.cpp#L591)

`getDependentDialects` is safe relative to the *pass pipeline* (it runs before `enterMultiThreadedExecution`), but it is too late relative to *parsing*. If a dialect's ops appear in the input MLIR file, those ops were already parsed as `UnregisteredOpModel` before `getDependentDialects` ever runs. Registering the dialect afterwards frees those models and leaves existing `Operation` objects with dangling pointers.

### Is `getDependentDialects` useful at all then?

Short answer: it is useful, but only for **dialects whose ops are produced by the pass**, not for dialects whose ops appear in the input IR.

This limitation is well-known and has been discussed extensively in the MLIR community.

**[RFC: Revamp dialect registration](https://discourse.llvm.org/t/rfc-revamp-dialect-registration/1559)** — the RFC that introduced the current design explicitly states:

> The registry won't trigger the load of all dialects in the context ahead of time. Instead, the parser is taught to load dialects from the registry **lazily** as it encounters ops from an unknown dialect.

The intended fix for input-file dialects is to put the dialect factory in the **global `DialectRegistry` before the context is created** — the parser then lazy-loads it on first encounter. `getDependentDialects` is strictly for dialects a pass *produces*.

**[GitHub Issue #60569 — "Loading an unregistered dependent dialect of a pass is broken"](https://github.com/llvm/llvm-project/issues/60569)** confirms the exact failure mode:

> A pass declares `TestDialect` as a dependent dialect — so if `TestDialect` is not registered in the global registry, the pass will cause `TestDialect` to be loaded *after* parsing.

**[GitHub Issue #54859 — "Dependent dialects not loaded in dynamic pipelines"](https://github.com/llvm/llvm-project/issues/54859)** adds another limitation: `getDependentDialects` is only called by the top-level `PassManager::run()`. Nested or dynamic pass pipelines skip it entirely.

**[RFC: Dialect::registerDependentDialects](https://discourse.llvm.org/t/rfc-dialect-registerdependentdialects/4467)** captures the community debate:

> The fact that a dialect can load another one as dependent "creates a 'loophole,' and was characterized as 'more like hiding some bugs than anything else.'"

The upshot: `getDependentDialects` is a useful narrow tool — it ensures dialects are available to passes before multi-threaded execution begins. It does **not** help when the dialect's ops appear in the input file. For that, the dialect must be in the global registry before `processBuffer` creates the `MLIRContext`.

### The MLIR idiomatic way to register a dialect dynamically

MLIR offers two patterns for dialects not known at compile time.

**Pattern 1 — `DialectRegistry::insertDynamic`** ([Defining Dialects docs](https://mlir.llvm.org/docs/DefiningDialects/), [D125201](https://reviews.llvm.org/D125201)):

```cpp
registry.insertDynamic("dialectName", [](MLIRContext *ctx, DynamicDialect *d) {
    // register dynamic ops/types/attrs here
});
```

The registry is populated **before** `MlirOptMain` creates the `MLIRContext`. The parser lazy-loads the dialect on first encounter of any op with that namespace — no `UnregisteredOpModel`, no use-after-free.

Limitation: `insertDynamic` only supports dynamic ops/types/attrs. It **cannot** override the dialect's virtual methods (`parseAttribute`, `printType`, etc.). CREST needs those overrides to dispatch into Scheme, so it uses the lower-level `DialectRegistry::insert(TypeID, name, factory)` instead — but the key constraint is the same: the factory must be in the registry before the context is created.

#### Class hierarchy: `CrestDialect` vs `DynamicDialect`

`CrestDialect` and `DynamicDialect` are **siblings** — both derive from `ExtensibleDialect`, neither inherits from the other:

```
mlir::Dialect
  └── mlir::ExtensibleDialect          (ExtensibleDialect.h)
        ├── mlir::DynamicDialect        (: SelfOwningTypeID, ExtensibleDialect)
        │     TypeID: self-owned via SelfOwningTypeID
        │     Registered via: insertDynamic / getOrLoadDynamicDialect
        │     Virtual overrides: only generic dynamic type/attr parsing
        │
        └── crest::CrestDialect         (: ExtensibleDialect)
              TypeID: g_crest_type_id_allocator (TypeIDAllocator)
              Registered via: DialectRegistry::insert(typeId, name, factory)
              Virtual overrides: all virtuals dispatch to Scheme callbacks
```

Key difference: `isa<DynamicDialect>(crestDialect)` returns **false**. A `CrestDialect` is an `ExtensibleDialect` but not a `DynamicDialect`. This matters for `insertDynamic`: it creates a `DynamicDialect` via `getOrLoadDynamicDialect`, which is incompatible with `CrestDialect`'s virtual dispatch into Scheme. CREST must use `insert(TypeID, name, factory)` directly.

Relevant sources: [`ExtensibleDialect.h:631`](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/include/mlir/IR/ExtensibleDialect.h#L631) (DynamicDialect definition), [`Dialect.cpp:228`](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/IR/Dialect.cpp#L228) (insertDynamic implementation), [`MLIRContext.cpp:536`](https://github.com/llvm/llvm-project/blob/ca7933e47d3a/mlir/lib/IR/MLIRContext.cpp#L536) (getOrLoadDynamicDialect).

**Pattern 2 — `--load-dialect-plugin`** ([DialectPlugin.h](https://github.com/llvm/llvm-project/blob/main/mlir/include/mlir/Tools/Plugins/DialectPlugin.h)):

Compile a shared library exposing:
```cpp
extern "C" ::mlir::DialectPluginLibraryInfo mlirGetDialectPluginInfo() {
    return { MLIR_PLUGIN_API_VERSION, "MyDialect", "v0.1",
             [](DialectRegistry *r) { r->insert<MyDialect>(); } };
}
```
`mlir-opt --load-dialect-plugin=libMyDialect.so` loads the library and calls the callback **before** context creation. The dialect is then in the global registry when the parser runs. This is the fully idiomatic solution for third-party runtime dialects.

**Both patterns share the same requirement:** the dialect factory must reach the `DialectRegistry` **before** `MLIRContext` is constructed, so the parser can find and lazily load the dialect by name during parsing.

### Implication for CREST's `dialects-in-scheme=` option

`dialects-in-scheme=` registers a Scheme-defined dialect via `getDependentDialects` — **correct for ops that the pass creates** during `runOnOperation`. The dialect is in the registry before any pass runs; new ops created by the pass see it as registered.

**However**, if the Scheme-defined dialect's ops appear in the **input MLIR file**, the ops are parsed as `UnregisteredOpModel` instances (before `getDependentDialects` runs). When the dialect is later registered, those models are freed, leaving existing `Operation` objects with dangling `OperationName` pointers.

The `interface-dsl` test exercises this case: `ifacetest.func` is in the input IR. The idiomatic fix (mirroring Pattern 2 above) is a top-level `--crest-preload-scheme-dialect=passes/ifacetest` flag in `crest-opt.cpp` that, before `MlirOptMain` runs, initializes the Chez interpreter, imports the library, and inserts the dialect factory into the global `DialectRegistry`. The parser then lazy-loads `ifacetest` on first encounter — no `UnregisteredOpModel`, no use-after-free. Alternatively, the test can be restructured so `ifacetest.func` ops are created programmatically by the pass rather than parsed from input.
