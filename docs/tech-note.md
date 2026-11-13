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

---

## Interfaces of a Scheme op: the interface map of its definition

An op of a C++ dialect gets every interface at compile time: `RegisteredOperationName::insert` builds an
`OperationName::Impl` whose `InterfaceMap` holds a pointer to the `Concept` of each interface (a struct of function
pointers, the vtable of the interface). `mlir::dyn_cast<FunctionOpInterface>(op)` and
`op->getName().hasInterface<FunctionOpInterface>()` are one lookup in that map.

A Scheme op is a `DynamicOpDefinition`, which is such an `Impl` with an empty map. Until the op-level
`:interfaces` clause was reworked (2026-11) CREST kept its `Concept`s in a separate table keyed by interface and op *name*
(`g_op_interface_registry`), reached through the `getRegisteredInterfaceForOp` hook of the dialect, which is only
consulted by `dyn_cast` on an `Operation`. `hasInterface`, `getInterface` and the checks of passes that run on an
interface (`InterfacePass::canScheduleOn`) read the `InterfaceMap` only, so they said "no" for every Scheme op. The
table was also process-wide: an op name had its interfaces in a context that never loaded the dialect.

Now the interfaces are part of the definition. `register-dynamic-op!` takes the list of `(TypeID . dispatcher)` pairs
of the op's `:interfaces` entries (the macro of each interface library makes the pair, see
`scheme/mlir/Interfaces/InferTypeOpInterface.sls`), and `lib/Crest/Op.cpp` finds the **attach function** of each
interface by its `TypeID` in a static table. The attach function inserts a *model* into
`def.getInterfaceMap()`: `crest::CrestModel<mlir::XInterface>` (`lib/Crest/Interface.h`), which is the interface's
`Concept`, the table of function pointers that MLIR calls, with `using Interface = ...;` and **every slot null**
(`lib/Bindings/Interfaces/*.cpp`, `lib/Bindings/IR/SymbolInterfaces.cpp`, `lib/Crest/InferType.cpp`).
`InterfaceMap::insertModels` default-constructs it in `malloc`ed memory and frees it with the map, so a model must be
trivially destructible. **C++ implements no method of any interface.** The attach function asks the dispatcher for the
entry point of each method and puts it in its slot (`installInterfaceEntry`), and MLIR calls Scheme directly. Where a
method has no clause, the dispatcher answers what the macro of the interface decided, all in `scheme/mlir/**`:

- a **default written in Scheme**, when MLIR has one for the method (`SymbolOpInterface`, the verifiers and
  `cloneTypeWith` of `FunctionOpInterface`, `refineReturnTypes` and `isCompatibleReturnTypes`, ...), so that an op that
  gives no clause gets what a C++ op gets from the `Trait` of the interface;
- the address of a **C function that CREST ships**, when the slot is one that Scheme cannot write because its answer is
  a C++ object that Scheme cannot build (`getArgOperandsMutable`: a `MutableOperandRange`; `getSymbolUses`: a use
  range). The clause names it (`(getArgOperandsMutable :all-operands)`) or it is MLIR's default for the method;
- an error when the library compiles, when MLIR has no default and the op gave no clause.

`scheme/crest/interface.sls` (`op-interface-expand`) does the work once for every interface: the macro of an interface
is a table of methods (the C++ types of the slot, an adapter, a default, the keywords), and the expander checks the
clauses and builds the dispatcher.

**The prototype of a slot as a C function** depends on the platform for some C++ types, and `crest-make-static-c-callable`
(`scheme/crest/callback.sls`) writes it from the C++ types of the slot. `unittests/Crest/InterfaceTest.cpp`
(`SlotAbiTest`) calls a callable of each kind through a function pointer of the exact type of the slot, on every
platform that CI runs. What Linux x86-64 and Windows x64 do:

| C++ type in a slot | Linux x86-64 | Windows x64 |
|---|---|---|
| a pointer, `bool`, an enum, an integer | a number | a number |
| a class of one pointer taken by value (`TypeAttr`, `StringAttr`, `CallInterfaceCallable`) | a number | a number |
| a class of one pointer **answered** by value (`Type`, `StringAttr`, `CallInterfaceCallable`) | a number | through a pointer that the caller gives, before the `Concept` |
| `llvm::LogicalResult` answered | a byte | through a pointer, like the class of one pointer |
| `ArrayRef`, `OperandRange` answered; `TypeRange` taken | two registers, or a struct: Chez `(& ftype)` | a pointer to a copy: Chez `(& ftype)` |

A `TypeRange` is not an array (its first word is a tagged union), so `crest::TypeRange::toList` reads one. An
`ArrayRef` that a callable answers has to outlive the call: `crest::CallableOpInterface::keepTypes` keeps the types
where the context owns them. arm64 is not tested.

An interface that extends others (`FunctionOpInterface` extends `SymbolOpInterface`, `ArgAndResultAttrsOpInterface` and
`CallableOpInterface`; `CallableOpInterface` and `CallOpInterface` extend `ArgAndResultAttrsOpInterface`) needs them in the
map first: the `Concept` looks them up in `initializeInterfaceConcept`, which `insertModels` calls. The attach
functions insert the bases once (`insertModelOnce` in `lib/Crest/Interface.h`), with null slots, and then their own
model. A base is filled only if the op declares it, so the op declares every base (`func.func` has them as traits
too), and `require*Clauses` (`lib/Bindings/Interfaces/CallInterfaces.cpp`, `lib/Bindings/IR/SymbolInterfaces.cpp`)
raises a Scheme error, when the op is registered, if a base model still has a null slot.
`mlir::function_interface_impl::printFunctionOp` on an op that does not declare `FunctionOpInterface` is an error, not a
guess. The trait `pure` fills the two slots of `MemoryEffectOpInterface` and `ConditionallySpeculatable` with fixed
answers (`addNoMemoryEffects`, `addAlwaysSpeculatable`): that is what `pure` means, and a clause of the op replaces
them.

The Scheme-callable accessors (`mlir::FunctionOpInterface::getFunctionType` and the others) look the `Concept` up in the
registered name of the op (`lookupConcept`), so they work for C++ ops as well. The one thing a context needs is the
dialect: an op of a dialect that was not loaded is an unregistered op and has no interfaces.

`unittests/Crest/InterfaceTest.cpp` asks the map of an op of each interface, and of one with none.

### Implication for CREST's `dialects-in-scheme=` option

`dialects-in-scheme=` registers a Scheme-defined dialect via `getDependentDialects` — **correct for ops that the pass creates** during `runOnOperation`. The dialect is in the registry before any pass runs; new ops created by the pass see it as registered.

**However**, if the Scheme-defined dialect's ops appear in the **input MLIR file**, the ops are parsed as `UnregisteredOpModel` instances (before `getDependentDialects` runs). When the dialect is later registered, those models are freed, leaving existing `Operation` objects with dangling `OperationName` pointers.

The `interface-dsl` tests avoid it by loading the dialect into the context (`load-scheme-dialect!`) before they parse the input. The idiomatic fix (mirroring Pattern 2 above) is a top-level `--crest-preload-scheme-dialect=passes/ifacetest` flag in `crest-opt.cpp` that, before `MlirOptMain` runs, initializes the Chez interpreter, imports the library, and inserts the dialect factory into the global `DialectRegistry`. The parser then lazy-loads `ifacetest` on first encounter — no `UnregisteredOpModel`, no use-after-free. Alternatively, the test can be restructured so `ifacetest.func` ops are created programmatically by the pass rather than parsed from input.

## Chez Scheme pin

`cmake/deps.cmake` fetches Chez Scheme from `https://github.com/cisco/ChezScheme.git` at a fixed commit.

| | Commit | Committed | Version |
|---|---|---|---|
| now | `d533f2e156d4eddeafe24bd7cc4de87fdc88caeb` ("use native fused multiply-add instructions for flfma (#1095)") | 2026-11-07 | 10.5.0 (`scheme-version` `#x0a050002`) |
| before | `e95a7efbafa2cf3bd5343ea542e6bc909a7ab2c4` | 2026-05-11 | 10.4.1 |

### Why the pin moved (2026-11-10)

A Chez `foreign-callable` on Windows x64 did not preserve `xmm6` to `xmm15` in full. The Windows x64 ABI makes
them callee-saved. The entry and exit code of the callable (`s/x86_64.ss`, `asm-foreign-callable`) saved
`xmm6` to `xmm11` as 64-bit doubles, and restoring with `movsd` zeroes the upper 64 bits of the register. Chez
never uses `xmm12` to `xmm15`, so those were not affected. C++ compiled for LLVM 23 keeps 16-byte values in these
registers across a call (a `Block::iterator`, restored by an `InsertionGuard`), so a call into a callable
changed them. The upstream repair is
[cisco/ChezScheme#1064](https://github.com/cisco/ChezScheme/pull/1064) "Windows x64: repair XMM register
preservation by callables", merged 2026-09-17 (`f6a0279d4`); the issue is
[racket/ChezScheme#66](https://github.com/racket/ChezScheme/issues/66). The pin of 2026-05-11 predates it.

Until 2026-11-10 CREST worked around it: every call from C++ into a callable went through a guard
(`crest::callForeign`, `XmmGuard.h` and a MASM routine, `XmmGuard_x64.asm`) that saved and restored the registers.
That did not cover MLIR calling the function pointers of the `InferTypeOpInterface` Concept by itself. With the
repaired Chez the callable preserves the registers, and the guard was removed. The regression tests are
`unittests/Crest/InferTypeTest.cpp`, `DirectCallPreservesVectorRegisters`, and
`unittests/Interpreter/InterpreterTest.cpp`, `CallablePreservesVectorRegisters`: both fail on Windows x64
with a Chez that does not preserve them.

### Why this commit

It is the newest commit of the upstream `main` when the pin was moved, 2026-11-10, not the merge of #1064 alone
(`f6a0279d4`, 2026-09-17): that way the pin has the repairs since, among them those of the x86-64 foreign call and
callable arguments (`048879e36`, 2026-11-05). The titles of the upstream commits after #1064 (checked 2026-11-10) show no revert of it and no repair of a
bug in it.

### How to move the pin again

1. Take a commit of `main` that is past the repair you need and look at its history for reverts.
2. Set `GIT_TAG` in `cmake/deps.cmake`, and update the comment above it (commit, date, version, reason).
3. The Windows build names the kernel library after the version, `csv<major><minor><patch>.lib`: `csv1050.lib` for
   10.5.0. Change `CHEZ_KERNEL_LIB` in the `WIN32` branch of `cmake/deps.cmake` when the version changes. The
   version is `scheme-version` in `s/cmacros.ss` of the Chez source.
4. The Windows CI keeps the Chez source, build and stamps in `C:\Develop\crest-deps`, which survive a wiped
   `build\`, and passes `FETCHCONTENT_UPDATES_DISCONNECTED=ON`, which skips the git update: an existing source
   directory is **not** moved to a new `GIT_TAG` (the first CI run after the 2026-11-10 bump compiled the old
   10.4.1 source and failed to find `csv1050.lib`). A new pin therefore needs new directories: in
   `.github/workflows/ci.yml` change `FETCHCONTENT_BASE_DIR`, `CHEZ_BUILD_DIR` and the `safe.directory` of the
   Windows configure step to a directory named after the short commit (`C:\Develop\crest-deps\d533f2e`).
   The stamps are named after the build directory.
5. The Linux CI caches the Chez build under a key of `hashFiles('cmake/deps.cmake')`, so editing `deps.cmake`
   rebuilds it.
6. Run both LLVM suites (`check-crest` and `CrestInterpreterTests`, `CrestInferTypeTests`) on Linux and let the
   Windows CI run.

## Chez Scheme leak: errors that escape through a C function

Chez 10.5.0 (`d533f2e`, and upstream `main` today) leaks about 208 bytes every time a Scheme error escapes through a
C function that had called into Scheme (`S_call_help`, `c/schlib.c`, "case 1: normal return": `CCHAIN(tc) = yp;` runs
before the loop that is meant to free the escaped frames). We do not patch Chez. `cmake/patches/chez-release-escaped-frames.patch`
is kept for the record, with a standalone repro in `cmake/patches/chez-error-escape-leak/`, the list of our tests that
reach it, what is known about upstream and how sure we are; the build does not apply it. CREST avoids the leak by
never letting an error cross a C function: a C++ binding returns an error `(who . why)` and Scheme raises it
(`plans/04-errors-are-values.md`). A callback (C++ calls Scheme) has the prototype that MLIR declares and reports an error of its
procedure as a diagnostic at its Scheme source, or ends the process when its result is `void` (CLAUDE.md Rule 17,
`plans/05-callables-match-mlir-prototypes.md`).

## Checking for memory leaks

The suite can run under valgrind, one test at a time, so that each record names its test. Copy the generated
`lit.site.cfg.py` of the build to another directory and add, after its `load_config` line:

    config.substitutions.insert(0, ("%scheme-mlir", "/tmp/vgbin/scheme-mlir"))
    config.substitutions.insert(0, ("%crest-opt", "/tmp/vgbin/crest-opt"))
    import os
    config.environment["VG_TAG"] = os.environ.get("VG_TAG", "none")

where each wrapper is `exec valgrind -q --leak-check=full --show-leak-kinds=definite,possible --num-callers=14
--log-file=/tmp/vglogs/${VG_TAG}.<tool>.%p.log <real binary> "$@"`. Run
`VG_TAG=<name> lit -q <dir> --filter "CREST :: <test>$"` for each test, then read the logs: "definitely lost" is a
leak, "Invalid read" is a use-after-free. `pass-leak`, `assembly-format-leak` and `llvm-ir-leak` fail under valgrind
(they measure the heap themselves) and report warnings that come from inside LLVM's printer and optimizer. The
first two found the leaks of Rule 20 in 2026-11.
