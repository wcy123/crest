<!--
Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
Licensed under the MIT License.
-->

**Date:** 2026-11-04
**Document Type:** Design
**Status:** Draft
**Related:** [architecture.md](architecture.md) (where the FFI bindings sit), [manual.md](manual.md#context-parameters) (`current-OpBuilder` holds a raw pointer), [manual.md](manual.md#11-extending-with-custom-c-bindings) (writing your own bindings)

---

# CrestObject

## Overview

Scheme holds a C++ object as a plain integer: its address. The address does not say what
type the object has, or who must free it. A **CrestObject** solves both. It is a C++ object
whose first field is a function pointer, the **deletor**. The deletor identifies the type
and frees the object.

## Contents

- [What a CrestObject is](#what-a-crestobject-is)
- [Why we need it](#why-we-need-it)
- [CrestOwned and CrestRef](#crestowned-and-crestref)
- [Memory diagrams](#memory-diagrams)
- [Using a shell in a binding](#using-a-shell-in-a-binding)
- [Pitfalls](#pitfalls)

---

## Design

### What a CrestObject is

Across the FFI, a pointer is an `uptr`: a Scheme integer that holds an address. The Scheme
garbage collector does not manage what it points to.

An address can point at one of two things:

- **A bare MLIR object**, for example `Operation*`, `MLIRContext*`, or the raw `OpBuilder*`
  in `current-OpBuilder`. Nothing sits in front of it.
- **A CrestObject.** This doc calls it a **shell**: the wrapper that Scheme holds in place
  of the C++ object.

Every shell starts with one 8-byte field, the **deletor**:

```
        CrestObject
   +0   +------------------------------+
        | deletor : void (*)(void*)    |   8 bytes
   +8   +------------------------------+
        | fields of the derived class  |
        | ...                          |
        +------------------------------+
```

The deletor is a function pointer. It does two jobs:

1. **It frees the object.** Calling `deletor(self)` runs the destructor and frees memory.
2. **It tells the type.** Every C++ type has its own deletor function, so the function's
   address identifies the type. The check `obj->isa<T>()` compares two addresses:
   `deletor == AsCrest<T>::type_deletor`.

A class becomes a CrestObject by inheriting `AsCrest<YourClass>`. Its constructor sets the
deletor, so you cannot forget it.

### Why we need it

With only an `uptr`, a binding cannot tell a `Value` from a builder, and cannot tell
whether Scheme must free the object. A shell answers both questions at run time.

**The program can check the type.** A shell has its type tag in the first 8 bytes. A
binding checks the tag before it uses the shell. If you pass the wrong object, you get a
clear Scheme error, `wrong CrestObject type`. Without the tag, the program would crash
deep inside MLIR. The tag also lets one function accept more than one kind of object. For
example, `as_ptr<mlir::OpBuilder>` accepts a `CrestOwned<OpBuilder>` or a
`CrestRef<RewriterBase>`.

**The object frees itself.** Scheme does not know the C++ type of the object it holds. We
also do not want a separate "free" binding for every type. So each shell carries its own
free function. `with-CrestObject` calls one C function, `CrestObject::delete`, which calls
the function stored in the shell. That function knows the real type. One macro works for
every object, and the object is freed exactly when the body ends. It is not freed later,
when the garbage collector happens to run.

```scheme
(with-CrestObject (state (mlir::OperationState::create loc "my.op"))
  ...)            ; leaving the body, normally or by exception, deletes `state`
```

### CrestOwned and CrestRef

Two templates cover almost every case.

| | `CrestOwned<T>` | `CrestRef<T>` |
|---|---|---|
| What the shell holds | a whole `T`, stored inside it | a pointer `T*` |
| Size | 8 + `sizeof(T)`, plus padding | 16 bytes |
| Who owns the `T` | the shell | someone else (MLIR) |
| What the deletor frees | the shell **and** the `T` | the shell **only** |
| Who creates it | a binding, with `new` | C++ code, around an object MLIR passes in |
| Who frees it | Scheme, with `with-CrestObject` | C++ (a `unique_ptr`) |
| Examples | `OpBuilder` from `atBlockEnd`, `RewritePatternSet`, `TypeConverter`, `ConversionTarget`, `OperationState` | the `RewriterBase` in a pattern callback |

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

### Memory diagrams

#### `CrestOwned<OpBuilder>`, from `mlir::OpBuilder::atBlockEnd`

```
                   variable `shell` (Chez Scheme: one machine word, no heap object)
                   +------------------------------+
   Scheme          | 0x2993BD20  | 000            |   = 0x14C9DE900, the address * 8
                   +------------------------------+
                     address       fixnum tag (binary)
                     |
                     |  FFI call, argument type `uptr`:
                     |  shift right by 3, which drops the tag
                     v
                   `uptr` (C `unsigned long`; our bindings take it as uint64_t)
                   +------------------------------+
   C++ call        | 0x2993BD20                   |   the shell address
                   +------------------------------+
                     |
                     |  points to
                     v
   address
   0x2993BD20  +0  +------------------------------+   CrestOwned<OpBuilder>, 40 bytes
                   | deletor ---------------------------------> AsCrest<CrestOwned<OpBuilder>>
   0x2993BD28  +8  +------------------------------+                 ::type_deletor
                   | context                      |  \
   0x2993BD30  +16 +------------------------------+   |
                   | listener                     |   |  inner : mlir::OpBuilder
   0x2993BD38  +24 +------------------------------+   |  (32 bytes)
                   | block                        |   |
   0x2993BD40  +32 +------------------------------+   |
                   | insertPoint                  |  /
   0x2993BD48  +40 +------------------------------+
```

The Scheme variable does not point at a Scheme object that points at the shell. It holds the
address itself, as a **fixnum**. In Chez Scheme's C header, a Scheme value has the C type
`ptr`, and `uptr` is `unsigned long`. A fixnum `n` is stored as the machine word `n * 8`, so
its low 3 bits are the tag `000`. The garbage collector sees a fixnum, not a pointer, so it
never moves or frees the shell. At an FFI call, the stub shifts the word right by 3 to get
the `uptr`.

An address is read from the `uptr` as follows:

| Integer value | How Chez Scheme stores it | Extra memory access |
|---|---|---|
| below 2^60 | fixnum: one word, the value times 8 | none |
| 2^60 or above | bignum: a pointer to a heap object, a header word (type, length, sign) followed by 32-bit digits | one |

User-space addresses on x86-64 are below 2^47, so a shell address is always a fixnum. The
shell address `0x2993BD20` in the diagram was measured on a `CrestOwned<MLIRContext>`: it is
a fixnum, and `most-positive-fixnum` is `0xFFFFFFFFFFFFFFF` (2^60 - 1). The word
`0x14C9DE900` is that address times 8. The other addresses in the heap box are that base
address plus the field offsets.

`with-OpBuilder` binds the **raw** address of `inner` (shell + 8) to its variable. It frees
the whole shell when the body exits. Code that only creates ops uses the raw pointer.

#### `CrestRef<RewriterBase>`, the rewriter in a pattern callback

MLIR passes the rewriter to the pattern. The C++ code wraps it in a `CrestRef` and calls the
Scheme callback with that shell.

```
 Scheme              C++ code (heap, in a unique_ptr)         MLIR (the driver owns this)
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
                                               | OpBuilder part          |   |
                                               |   context          +8   |   |
                                               |   listener        +16   |   |
                                               |   block           +24   |   |
                                               |   insertPoint     +32   |   |
                                           +40 +-------------------------+   |
                                                                             |
        (crest::as_ptr<mlir::OpBuilder> rw)  ----------------------------------+
        returns the RewriterBase address + 8: the raw OpBuilder* in current-OpBuilder
```

The `OpBuilder` does **not** start at the beginning of the `RewriterBase`. `RewriterBase` has
virtual functions, so it starts with a hidden pointer to its virtual table (`vptr`).
`OpBuilder` has no virtual functions and comes after it. Converting a `RewriterBase*` to an
`OpBuilder*` in C++ adds 8 bytes. Code that reuses the same address would read the `vptr` as
the builder's `context`. For this reason the conversion is done in C++
(`as_ptr<mlir::OpBuilder>`), and `current-OpBuilder` holds the adjusted raw pointer.

#### What happens when `with-CrestObject` ends

```
 (with-CrestObject (b (mlir::OpBuilder::atBlockEnd blk)) body ...)

 Scheme                      C function                    function stored in the shell
 ------                      ----------                    ----------------------------
 CrestObject::delete b  -->  obj->deletor(obj)  ------->  type_deletor<CrestOwned<OpBuilder>>(self)
                                                              |
                                                              v
                                                          delete static_cast<CrestOwned<OpBuilder>*>(self)
                                                          (runs ~OpBuilder, then frees the shell)
```

Scheme only has `obj`. The deletor was set when the object was built, so it knows the type.

#### The three kinds of address

| | raw pointer | `CrestOwned<T>` | `CrestRef<T>` |
|---|---|---|---|
| What Scheme holds | address of the `T` | address of the shell | address of the shell |
| Type tag at +0 | no | yes | yes |
| What a binding checks | not null | type tag | type tag |
| Freed by Scheme | never | yes, with `with-CrestObject` | never |
| Examples | `Operation*`, `Block*`, raw `OpBuilder*`, raw `MLIRContext*` | `OpBuilder` from `atBlockEnd`, `RewritePatternSet` | the pattern's rewriter |

### Using a shell in a binding

The binding helpers have one function for each kind of argument. Pick the one that matches
what Scheme passes.

| Function | Accepts | Returns | Use it when |
|---|---|---|---|
| `as_raw<T>(p, who)` | a raw `T*` | `T*` | MLIR owns the object and there is no shell. Only checks for null. |
| `as_ptr<T>(p, who)` | `CrestRef<T>*` or `CrestOwned<T>*` | `T*` | either kind of shell is fine |
| `as_ref<T>(p, who)` | `CrestOwned<T>*` | `T&` | the argument must be an owned object |
| `crest_cast<X>(p, who)` | a shell of exactly type `X` | `X*` | the argument is one specific shell type |

Two types have a special `as_ptr`, because their objects arrive in more than one form:

- `as_ptr<mlir::MLIRContext>` also accepts a raw `MLIRContext*`, such as the one from
  `op->getContext()`.
- `as_ptr<mlir::OpBuilder>` accepts `CrestOwned<OpBuilder>` and `CrestRef<RewriterBase>`,
  and adds the 8 bytes described above. It rejects a raw pointer. A binding that takes a
  builder takes the raw `OpBuilder*` and calls `as_raw`.

The `isa` check is **exact**. A `CrestRef<RewriterBase>` is not a `CrestRef<PatternRewriter>`.
For this reason, each shell type that is accepted is listed by name.

`CrestOwned<T>` needs a public destructor on `T`, because its deletor runs `delete`.
`RewriterBase` has a protected destructor, so Scheme can hold it only through `CrestRef`.

The Scheme side, in `(mlir support array-ref)`:

| Binding | What it does |
|---|---|
| `with-CrestObject` | frees any shell when the body exits |
| `CrestObject::delete` | calls the deletor now |
| `CrestObject::deletor` | reads the type tag: `(foreign-ref 'uptr obj 0)` |

### Pitfalls

- **Never free a `CrestRef`.** C++ owns it. Calling `with-CrestObject` on the rewriter
  shell frees the shell twice.
- **A `CrestRef` is valid only inside the callback.** The C++ code destroys the shell when
  the callback returns, and MLIR owns the object behind it. Do not store either one.
- **A shell address is not an `OpBuilder*`.** If you pass a `CrestOwned<OpBuilder>` where a
  raw `OpBuilder*` is expected, the binding reads the deletor as the builder's `context`.
  Unwrap the shell with `as_ptr<mlir::OpBuilder>`, or use `with-OpBuilder`.
- **The type tag is a function address.** It is unique only if every shared library sees the
  same `type_deletor`. `CREST_VISIBLE` forces default ELF visibility, so the dynamic linker
  merges the copies. On Windows each DLL keeps its own copy, so `isa<T>` is not safe for an
  object that crosses a DLL boundary.

---

## Related Documents

- [architecture.md](architecture.md) - the FFI bindings layer that uses CrestObject
- [manual.md](manual.md#context-parameters) - why `current-OpBuilder` holds a raw pointer, not a shell
- [manual.md](manual.md#11-extending-with-custom-c-bindings) - how to write a binding that takes or returns a shell
