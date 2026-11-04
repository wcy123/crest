<!--
Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
Licensed under the MIT License.
-->

**Date:** 2026-11-04
**Document Type:** Technical note
**Status:** Draft
**Related:** `lib/Bindings/Support/CrestObject.h`, `lib/Bindings/Support/SchemeWrapper.h`, [architecture.md](architecture.md)

---

# CrestObject

A **CrestObject** is a small C++ header placed in front of a heap object that Scheme holds
a pointer to. The header tells the runtime two things about the object: what type it is,
and how to free it.

## Contents

- [1. What a CrestObject is](#1-what-a-crestobject-is)
- [2. Why we need it](#2-why-we-need-it)
- [3. CrestOwned and CrestRef](#3-crestowned-and-crestref)
- [4. Memory diagrams](#4-memory-diagrams)
- [5. Reading a handle in a binding](#5-reading-a-handle-in-a-binding)
- [6. Pitfalls](#6-pitfalls)

---

## 1. What a CrestObject is

Scheme cannot hold a C++ pointer directly. Across the FFI a pointer is an `uptr`: a plain
Scheme integer that holds an address. Scheme's garbage collector does not know about it.

Some of those addresses point at a bare MLIR object (`Operation*`, `MLIRContext*`, the raw
`OpBuilder*` in `current-OpBuilder`). Others point at a **CrestObject**.

Every CrestObject starts with one 8-byte field, the **deletor**:

```
        CrestObject
   +0   +------------------------------+
        | deletor : void (*)(void*)    |   8 bytes
   +8   +------------------------------+
        | fields of the derived class  |
        | ...                          |
        +------------------------------+
```

The deletor is a function pointer. It has two jobs:

1. **Destructor.** `deletor(self)` frees the object.
2. **Type tag.** Each C++ type gets its own deletor function, so its address identifies
   the type. `obj->isa<T>()` is one pointer comparison: `deletor == AsCrest<T>::type_deletor`.

A class becomes a CrestObject by inheriting `AsCrest<YourClass>`. The constructor of
`AsCrest` fills in the deletor, so it cannot be forgotten.

## 2. Why we need it

A bare address carries no information. With only an `uptr`, a binding cannot tell a
`Value` from a builder, or tell who must free it. We need two things at run time.

**Runtime type information.** Every binding that takes a shell checks the type tag first.
Passing the wrong object gives a Scheme error, `wrong CrestObject type`, instead of a
crash somewhere inside MLIR. The check also lets one function accept several shapes of
the same thing: `as_ptr<mlir::OpBuilder>` takes either a `CrestOwned<OpBuilder>` or a
`CrestRef<RewriterBase>`.

**The object frees itself.** Scheme does not know the C++ type of what it holds, and we do
not want one `free-this-type` binding per type. `with-CrestObject` calls the single
trampoline `CrestObject::delete`, which calls `obj->deletor(obj)`. The deletor knows the
real type and runs the right destructor. One generic RAII macro works for every object,
and the free happens at a known point, not whenever the garbage collector decides.

```scheme
(with-CrestObject (state (mlir::OperationState::create loc "my.op"))
  ...)            ; leaving the body, normally or by exception, deletes `state`
```

## 3. CrestOwned and CrestRef

Two templates cover almost every case. Both are defined in `CrestObject.h`.

| | `CrestOwned<T>` | `CrestRef<T>` |
|---|---|---|
| What it holds | a whole `T`, inline | a pointer `T*` |
| Size | 8 + `sizeof(T)` (plus padding) | 16 bytes |
| Who owns `T` | the shell | someone else (MLIR) |
| The deletor frees | the shell **and** the `T` | the shell **only** |
| Who creates it | a binding, with `new` | C++ glue, around an object MLIR passes in |
| Who frees it | Scheme: `with-CrestObject` | C++ (a `unique_ptr` in the glue) |
| Examples | `OpBuilder` (from `atBlockEnd`), `RewritePatternSet`, `TypeConverter`, `ConversionTarget`, `OperationState` | `RewriterBase` in a pattern callback |

Layouts on a 64-bit target:

```
   CrestOwned<T>                          CrestRef<T>
   +0  +----------------+                 +0  +----------------+
       | deletor        |                     | deletor        |
   +8  +----------------+                 +8  +----------------+
       | T inner        |                     | T* ptr  ------------> a T owned elsewhere
       | (sizeof(T))    |                 16  +----------------+
       +----------------+
```

`CArrayRef<T>` (in `Support/ArrayRef.h`) is a third CrestObject with its own fields: a
`data` pointer at +8 and a `size` at +16. The shell is freed like any CrestObject
(`with-ArrayRef`), but it never owns the elements.

## 4. Memory diagrams

### 4.1 `CrestOwned<OpBuilder>`, from `mlir::OpBuilder::atBlockEnd`

```
 Scheme                         C++ heap                                   code
 ------                         --------                                   ----

 shell = 0x55d0c8a04e10 ---+
 (an exact integer)        |
                           v
                       +0  +------------------------------+
                           | deletor ---------------------------------> AsCrest<CrestOwned<OpBuilder>>
                       +8  +------------------------------+                 ::type_deletor
                           | context                      |  \
                      +16  +------------------------------+   |
                           | listener                     |   |  inner : mlir::OpBuilder
                      +24  +------------------------------+   |  (32 bytes)
                           | block                        |   |
                      +32  +------------------------------+   |
                           | insertPoint                  |  /
                      +40  +------------------------------+

                           CrestOwned<OpBuilder> = 40 bytes
```

`with-OpBuilder` binds the **raw** address of `inner` (shell + 8) to its variable and frees
the whole shell on exit. Code that only needs to create ops uses the raw pointer.

### 4.2 `CrestRef<RewriterBase>`, the rewriter in a pattern callback

MLIR passes the rewriter into `matchAndRewrite`. The C++ glue wraps it in a `CrestRef`
and calls the Scheme callback with the shell.

```
 Scheme              C++ glue (heap, in a unique_ptr)         MLIR (the driver owns this)
 ------              --------------------------------         ---------------------------

 rw = 0x7f3a...  --> +0  +-------------------+
                         | deletor ---------------> CrestRef<RewriterBase>::type_deletor
                     +8  +-------------------+
                         | ptr  ---------------+
                     +16 +-------------------+ |
                      CrestRef<RewriterBase>   |
                      16 bytes                 |
                                               v
                                           +0  +-------------------------+  RewriterBase
                                               | vptr                    |  (40 bytes)
                                           +8  +-------------------------+ <-+
                                               | OpBuilder subobject     |   |
                                               |   context          +8   |   |
                                               |   listener        +16   |   |
                                               |   block           +24   |   |
                                               |   insertPoint     +32   |   |
                                           +40 +-------------------------+   |
                                                                             |
        (crest::as_ptr<mlir::OpBuilder> rw)  ----------------------------------+
        returns RewriterBase address + 8:   the raw OpBuilder* in current-OpBuilder
```

The `OpBuilder` is **not** at the start of the `RewriterBase`, because `RewriterBase` has a
virtual function table and `OpBuilder` does not. Casting the `RewriterBase*` to an
`OpBuilder*` in C++ adds 8 bytes. A binding that did `reinterpret_cast` on the raw address
would read the vptr as the builder's `context`. This is why the conversion lives in C++
(`as_ptr<mlir::OpBuilder>`), and why `current-OpBuilder` holds the adjusted raw pointer.

### 4.3 What happens at the end of `with-CrestObject`

```
 (with-CrestObject (b (mlir::OpBuilder::atBlockEnd blk)) body ...)

 Scheme                      C trampoline                  deletor stored in the object
 ------                      ------------                  ----------------------------
 CrestObject::delete b  -->  obj->deletor(obj)  ------->  type_deletor<CrestOwned<OpBuilder>>(self)
                                                              |
                                                              v
                                                          delete static_cast<CrestOwned<OpBuilder>*>(self)
                                                          (runs ~OpBuilder, then frees the shell)
```

Scheme only knows `obj`. The deletor, picked when the object was built, knows the type.

### 4.4 The three kinds of handle

```
                       raw pointer              CrestOwned<T>            CrestRef<T>
                       -----------              -------------            -----------
 Scheme holds          address of T             address of shell         address of shell
 Type tag at +0?       no                       yes                      yes
 Checked by binding?   null check only          type tag                 type tag
 Freed by Scheme?      never                    yes (with-CrestObject)   never
 Examples              Operation*, Block*,      OpBuilder from           the pattern's
                       raw OpBuilder*,          atBlockEnd,              rewriter
                       raw MLIRContext*         RewritePatternSet
```

## 5. Reading a handle in a binding

`SchemeWrapper.h` has one function per kind of argument. Pick the one that matches what
Scheme passes.

| Function | Accepts | Returns | Use when |
|---|---|---|---|
| `as_raw<T>(p, who)` | a raw `T*` | `T*` | the object is owned by MLIR and has no shell (null check only) |
| `as_ptr<T>(p, who)` | `CrestRef<T>*` or `CrestOwned<T>*` | `T*` | either shell is fine |
| `as_ref<T>(p, who)` | `CrestOwned<T>*` | `T&` | the argument must be an owned object |
| `crest_cast<X>(p, who)` | a CrestObject of exactly type `X` | `X*` | the argument is a specific shell type |

Two specializations exist because an object can legitimately arrive in more than one shape:

- `as_ptr<mlir::MLIRContext>` also accepts a raw `MLIRContext*` (from `op->getContext()`).
- `as_ptr<mlir::OpBuilder>` accepts `CrestOwned<OpBuilder>` and `CrestRef<RewriterBase>`
  (with the +8 adjustment from section 4.2). It rejects a raw pointer. Bindings that
  take a builder take the raw `OpBuilder*` and call `as_raw`.

The `isa` test is **exact**. A `CrestRef<RewriterBase>` is not a `CrestRef<PatternRewriter>`,
so every accepted shell is listed by name.

`CrestOwned<T>` is only available when `T` has a public destructor, because its deletor
runs `delete` on the whole shell. `RewriterBase` has a protected destructor, so it is
only ever held through `CrestRef`.

On the Scheme side (`(mlir support array-ref)`):

| Binding | Meaning |
|---|---|
| `with-CrestObject` | free any CrestObject when the body exits |
| `CrestObject::delete` | call the deletor now |
| `CrestObject::deletor` | read the type tag: `(foreign-ref 'uptr obj 0)` |

## 6. Pitfalls

- **Never free a `CrestRef`.** C++ owns it. Calling `with-CrestObject` on the rewriter
  shell would free the shell twice.
- **A `CrestRef` is valid only inside the callback.** The glue destroys the shell when
  `scheme_call` returns, and MLIR owns the object behind it. Do not store either one.
- **A shell address is not an `OpBuilder*`.** Passing `CrestOwned<OpBuilder>` where a raw
  `OpBuilder*` is expected reads the deletor as the builder's `context`. Unwrap it with
  `as_ptr<mlir::OpBuilder>`, or let `with-OpBuilder` do it.
- **The type tag is a function address.** It is only unique if every shared library sees
  the same `type_deletor`. `CREST_VISIBLE` forces default ELF visibility so the dynamic
  linker merges the copies. On Windows each DLL keeps its own copy, and `isa<T>` is
  unsafe for objects that cross a DLL boundary.
