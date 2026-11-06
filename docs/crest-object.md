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
- [Two kinds of shell](#two-kinds-of-shell)
- [Memory diagrams](#memory-diagrams)
- [Cost of the extra level](#cost-of-the-extra-level)
- [Freeing shells](#freeing-shells)
- [Using a shell in a binding](#using-a-shell-in-a-binding)
- [Pitfalls](#pitfalls)

---

## Design

### What a CrestObject is

Scheme holds a C++ address as an ordinary integer. The C++ side sees the same address as a
`uptr` (`unsigned long`). The Scheme garbage collector does not manage what it points to.
[The first diagram below](#crestboxopbuilder-from-mliropbuilderatblockend) shows how Scheme
stores the integer.

An address can point at one of two things:

- **A bare MLIR object**, for example `Operation*` or `MLIRContext*`. Nothing sits in front of
  it.
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
deep inside MLIR. A C++ binding takes exactly one kind of shell. When Scheme may hold one of
several kinds, as it does for a builder, the Scheme side checks the type with an `isa`
predicate and calls the binding for that kind (`define-builder-binding`, below).

**The object frees itself.** Scheme does not know the C++ type of the object it holds. We
also do not want a separate "free" binding for every type. So each shell carries its own
free function. `with-CrestObject` calls one C function, `crest::CrestObject::delete`, which calls
the function stored in the shell. That function knows the real type. One macro works for
every object, and the object is freed exactly when the body ends. It is not freed later,
when the garbage collector happens to run.

```scheme
(with-CrestObject state (mlir::OperationState::create loc "my.op")
  ...)            ; leaving the body, normally or by exception, deletes `state`
```

### Two kinds of shell

`CrestBox<T>` covers almost every case. It has two forms: it holds a `T` itself, or, when its
argument is a pointer type `CrestBox<T*>`, it holds a pointer to a `T` that someone else
owns.

| | `CrestBox<T>` | `CrestBox<T*>` |
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
   CrestBox<T>                          CrestBox<T*>
   +0  +----------------+                 +0  +----------------+
       | deletor        |                     | deletor        |
   +8  +----------------+                 +8  +----------------+
       | T inner        |                     | T* ptr  ------------> a T owned elsewhere
       | (sizeof(T))    |                 16  +----------------+
       +----------------+
```

### Memory diagrams

#### `CrestBox<OpBuilder>`, from `mlir::OpBuilder::atBlockEnd`

```
Scheme object
(`ptr`)           +------------------------------+
                  | 0x14C9DE900                  |   = 0x2993BD20 << 3
                  +------------------------------+
                       |
                       |  FFI call: shift right by 3
                       |  gives the shell address (`uptr`) 0x2993BD20,
                       |  which is the address of the shell below
                       v
address      offset
0x2993BD20   +0   +------------------------------+   CrestBox<OpBuilder>, 40 bytes
                  | deletor ---------------------------------> AsCrest<CrestBox<OpBuilder>>::type_deletor
0x2993BD28   +8   +------------------------------+
                  | context                      |  \
0x2993BD30   +16  +------------------------------+   |
                  | listener                     |   |  inner : mlir::OpBuilder
0x2993BD38   +24  +------------------------------+   |  (32 bytes)
                  | block                        |   |
0x2993BD40   +32  +------------------------------+   |
                  | insertPoint                  |  /
0x2993BD48   +40  +------------------------------+
```

The Scheme variable holds the shell address as a Scheme integer. Chez Scheme stores an integer
that fits in 61 bits as a **fixnum**: the number shifted left by 3, so the low 3 bits are
`000`. In the C header of Chez Scheme, this stored word is called a `ptr`, and the plain
address is a `uptr` (`unsigned long`). Here:

| Name | Value | Meaning |
|---|---|---|
| `uptr` | `0x2993BD20` | the shell address; the C++ bindings receive it as a `uint64_t` argument, and it is not stored anywhere else |
| `ptr` | `0x14C9DE900` | the same number shifted left by 3; this is what the Scheme variable holds |

A fixnum is not a pointer. There is no heap object behind it, and the garbage collector does
not follow it, so it never moves or frees the shell. When Scheme calls a binding, the FFI
shifts the `ptr` right by 3 and passes the `uptr`.

There is one case with an extra memory access: an integer of 2^60 or more does not fit in a
fixnum. Chez Scheme stores it as a **bignum**, a heap object that holds a header word (type,
length, sign) followed by 32-bit digits. User-space addresses on x86-64 are below 2^47, so a
shell address is always a fixnum.

The shell address `0x2993BD20` was measured on a `CrestBox<MLIRContext>`, and
`most-positive-fixnum` is `0xFFFFFFFFFFFFFFF` (2^60 - 1). The `ptr` value `0x14C9DE900` is
computed with the shift, not read from the running program. The other addresses in the shell
box are the shell address plus the field offsets.

`with-OpBuilder` binds the **raw** address of `inner` (shell + 8) to its variable. It frees
the whole shell when the body exits. Code that only creates ops uses the raw pointer.

#### `CrestBox<RewriterBase*>`, the rewriter in a pattern callback

MLIR passes the rewriter to the pattern. The C++ code wraps it in a `CrestBox<RewriterBase*>` and calls the
Scheme callback with that shell.

```
 Scheme              C++ code (heap, in a unique_ptr)         MLIR (the driver owns this)
 ------              --------------------------------         ---------------------------

 rw = 0x7f3a...  --> +0  +-------------------+
                         | deletor ---------------> CrestBox<RewriterBase*>::type_deletor
                     +8  +-------------------+
                         | ptr  ---------------+
                     +16 +-------------------+ |
                      CrestBox<RewriterBase*>  |
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
        CrestBox<RewriterBase*>::inner, read as an OpBuilder&  ---------------+
        the C++ upcast adds 8: the OpBuilder base the builder bindings use
```

The `OpBuilder` does **not** start at the beginning of the `RewriterBase`. `RewriterBase` has
virtual functions, so it starts with a hidden pointer to its virtual table (`vptr`).
`OpBuilder` has no virtual functions and comes after it. Converting a `RewriterBase*` to an
`OpBuilder*` in C++ adds 8 bytes. Code that reuses the same address would read the `vptr` as
the builder's `context`. For this reason the conversion is done by C++ on the typed shell
(`CrestBox<RewriterBase*>::inner` returns a `RewriterBase&`, which converts to `OpBuilder&`).
`current-OpBuilder` keeps the shell, so a rewriter stays a rewriter and rewriter-only
operations still reach the real object.

#### What happens when `with-CrestObject` ends

```
 (with-CrestObject b (mlir::OpBuilder::atBlockEnd blk) body ...)

 Scheme                         C function                function stored in the shell
 ------                         ----------                ----------------------------
 crest::CrestObject::delete b   -->  obj->deletor(obj)  ------->  type_deletor<CrestBox<OpBuilder>>(self)
                                                                      |
                                                                      v
                                                                  delete static_cast<CrestBox<OpBuilder>*>(self)
                                                                  (runs ~OpBuilder, then frees the shell)
```

Scheme only has `obj`. The deletor was set when the object was built, so it knows the type.

#### The three kinds of address

| | raw pointer | `CrestBox<T>` | `CrestBox<T*>` |
|---|---|---|---|
| What Scheme holds | address of the `T` | address of the shell | address of the shell |
| Type tag at +0 | no | yes | yes |
| What a binding checks | not null | type tag | type tag |
| Freed by Scheme | never | yes, with `with-CrestObject` | never |
| Memory loads to reach the `T` | 0 | 1 (the type tag, then `T` is inline) | 2 (the type tag, then `ptr`, then the `T` is elsewhere) |
| Examples | `Operation*`, `Block*`, raw `MLIRContext*` | `OpBuilder` from `atBlockEnd`, `RewritePatternSet` | the pattern's rewriter |

### Cost of the extra level

A shell is one more level between Scheme and the object. A raw pointer has none. The shell
costs work in two places:

- **Every use.** A binding reads the type tag at +0 and compares it. For a `CrestBox<T*>` it
  then reads `ptr` at +8, and the `T` is in another place in memory. For a `CrestBox` the
  `T` is right after the tag.
- **Every creation.** Each shell is one heap allocation. For example, C++ allocates one
  `CrestBox<RewriterBase*>` each time a pattern matches an op name and calls its Scheme
  callback.

`current-OpBuilder` holds the shell anyway: a rewriter must stay a rewriter, so that
rewriter-only operations dispatch on the real object. Each builder binding pays the type-tag
check. The per-call cost has not been measured.

### Freeing shells

The Scheme garbage collector does not know about a `CrestBox` shell, because Scheme holds
only an integer. If Scheme drops that integer without freeing the shell, the memory is
**leaked** for the rest of the run. So every `CrestBox` shell must be freed exactly once,
and the `with-*` macros are how you do it.

#### `with-CrestObject`

```scheme
(with-CrestObject name (create-call)
  body ...)
```

`(create-call)` is the whole call that makes the shell, for example
`(mlir::OperationState::create loc "my.op")`. The macro binds `name` to that shell, runs the
body, and then calls `crest::CrestObject::delete` on the shell. It expands to this:

```scheme
(let ([name (create-call)])
  (dynamic-wind
    (lambda () #f)
    (lambda () body ...)
    (lambda () (crest::CrestObject::delete name))))
```

Because of `dynamic-wind`, the shell is freed in all three ways the body can end: it returns
normally, it raises a Scheme error, or it jumps out with a continuation. The value of the
form is the value of the body.

#### Macros built on it

Each of these creates one shell, binds it to a variable, and frees it when the body ends.
They share one shape: the variable first, then the creation arguments in a list, then the
body. The list is `()` when there are no arguments.

```scheme
(with-<Class> variable (arguments ...) body ...)
```

| Macro | What it creates |
|---|---|
| `with-CrestObject v (create-call)` | any shell: the general form, where `(create-call)` is the call that makes it |
| `with-OperationState v (loc name)` | a `CrestBox<OperationState>` |
| `with-RewritePatternSet v ()` or `v (ctx)` | a `RewritePatternSet` |
| `with-TypeConverter v ()` | a `TypeConverter` |
| `with-LLVMTypeConverter v ()` or `v (ctx)` | an `LLVMTypeConverter` |
| `with-ConversionTarget v ()` or `v (ctx)` | a `ConversionTarget` |
| `with-ExecutionEngine v (module-op)` | an `ExecutionEngine` |
| `with-ArrayRef v (ref)` or `v (data size)` | a `CArrayRef`; the elements are never freed |
| `with-OpBuilder v (create-call)` | frees the shell that `(create-call)` makes, and binds `v` to that shell |
| `with-DialectRegistry v ()`, `with-MLIRContext v (registry)`, `with-PassManager v (ctx)` | a `DialectRegistry`, an `MLIRContext` made from a registry, a `PassManager` |

Nested macros free in reverse order: the innermost shell is freed first.

#### Macros that free nothing

`with-current-MLIRContext`, `with-current-Block` and `with-current-OpBuilder` only set a
dynamic variable for the length of the body (see
[manual.md](manual.md#context-parameters)). They do not create or free anything. They are
often nested inside one of the macros above, for example `with-OpBuilder` for the shell and
`with-current-OpBuilder` to make its raw pointer the ambient builder.

#### How to avoid a leak

- **Create a `CrestBox` shell only inside a `with-*` macro.** If you call a binding that
  returns a shell (`mlir::OpBuilder::atBlockEnd`, `mlir::MLIRContext::new`, and so on) and
  do not pass the result to one of these macros or to `crest::CrestObject::delete`, it leaks.
- **Do not return the shell out of the body.** It is freed when the body ends, so the
  returned address would point at freed memory. Return what you need from it instead, for
  example the new op or value, which MLIR owns.
- **Do not free a `CrestBox<T*>`.** C++ frees it. A `with-CrestObject` around it frees it twice.
- **Do not re-enter a body with a saved continuation after it ended.** The shell is already
  freed.
- **A `guard` with no matching clause frees the shell twice.** It re-raises the error from
  inside the body, which re-enters the `dynamic-wind`, so the free runs a second time. Use a
  catch-all clause (`[#t ...]`) around a `with-CrestObject` body, as the pattern code does.
- **An error that nothing catches does not free the shell.** The free runs only when control
  leaves the body, and an uncaught error stops the process without unwinding.

### Using a shell in a binding

The binding helpers have one function for each kind of argument. Pick the one that matches
what Scheme passes.

| Function | Accepts | Returns | Type safety | Use it when |
|---|---|---|---|---|
| `as_raw<T>(p, who)` | a raw `T*` | `T*` | **none.** It only checks for null. Any address is cast to `T*`, so a wrong object gives undefined behavior, often a crash inside MLIR. | MLIR owns the object and there is no shell |
| `CrestBox<T>::inner(p, who)` | `CrestBox<T>*` | `T&` | **checked.** Null is a Scheme error, `null pointer`. The type tag must be `CrestBox<T>`; otherwise a Scheme error, `wrong CrestObject type`. | Scheme owns the object |
| `CrestBox<T*>::inner(p, who)` | `CrestBox<T*>*` | `T&` | **checked**, in the same way, against the tag of `CrestBox<T*>`. | C++ passes in an object MLIR owns, such as the `RewriterBase` of a pattern |

Only `as_raw` skips the check. The other two read the type tag first, which is the cost
described in [the cost section](#cost-of-the-extra-level). A binding names the shell type it
expects, so a `CrestBox<RewriterBase*>` is not accepted where a `CrestBox<RewriterBase>`
is expected.

On a typed shell (one that C++ created or already checked), the member `inner()` returns the
`T&` with no check.

Two types have a special `as_ptr`, because their objects arrive in more than one form:

- `as_ptr<mlir::MLIRContext>` also accepts a raw `MLIRContext*`, such as the one from
  `op->getContext()`. **It is not type-safe**: if the argument is not a
  `CrestBox<MLIRContext>`, it is cast to `MLIRContext*` with no check, like `as_raw`.
- A builder is one of three shells: `CrestBox<OpBuilder>` (from `atBlockEnd`),
  `CrestBox<RewriterBase*>` (a pattern's rewriter, adding the 8 bytes described above) and
  `CrestBox<OpBuilder*>` (a builder MLIR passes to a callback). Each C++ symbol takes exactly one,
  so `register_builder_binding` (`lib/Bindings/Support/BuilderBinding.h`) registers one body three
  times as `NAME<OpBuilder>`, `NAME<RewriterBase*>` and `NAME<OpBuilder*>`. On the Scheme side
  `define-builder-binding` (`(mlir support BuilderBinding)`) makes one procedure that checks the
  shell with the `isa` predicates and calls the matching symbol. A raw pointer or any other
  shell is a Scheme error.

The `isa` check is **exact**. A `CrestBox<RewriterBase*>` is not a
`CrestBox<PatternRewriter*>`. For this reason, each shell type that is accepted is listed by
name.

`CrestBox<T>` needs a public destructor on `T`, because its deletor runs `delete`.
`RewriterBase` has a protected destructor, so Scheme can hold it only through
`CrestBox<RewriterBase*>`.

The Scheme side, in `(mlir support CrestObject)`:

| Binding | What it does |
|---|---|
| `with-CrestObject` | frees any shell when the body exits |
| `crest::CrestObject::delete` | calls the deletor now |
| `crest::CrestObject::deletor` | reads the type tag: `(foreign-ref 'uptr obj 0)` |

### Pitfalls

- **Never free a `CrestBox<T*>`.** C++ owns it. Calling `with-CrestObject` on the rewriter
  shell frees the shell twice.
- **A `CrestBox<T*>` is valid only inside the callback.** The C++ code destroys the shell when
  the callback returns, and MLIR owns the object behind it. Do not store either one.
- **A raw `OpBuilder*` is not a builder handle.** Builder bindings take a shell. Passing a raw
  pointer is an error, and an address that is not a shell at all is undefined behaviour.
- **The type tag is a function address.** It is unique only if every shared library sees the
  same `type_deletor`. `CREST_VISIBLE` forces default ELF visibility, so the dynamic linker
  merges the copies. On Windows each DLL keeps its own copy, so `isa<T>` is not safe for an
  object that crosses a DLL boundary.

---

## Related Documents

- [architecture.md](architecture.md) - the FFI bindings layer that uses CrestObject
- [manual.md](manual.md#context-parameters) - why `current-OpBuilder` holds a raw pointer, not a shell
- [manual.md](manual.md#11-extending-with-custom-c-bindings) - how to write a binding that takes or returns a shell
