#pragma once

#include <cstdint> // uint64_t
#include <utility> // std::forward for CrestBox<T> constructor

// Symbol-visibility macro for type_deletor.
// Forces default (exported) visibility so the dynamic linker can unify copies
// of type_deletor across DSO boundaries, keeping isa<T>() comparisons safe.
#if defined(__GNUC__) || defined(__clang__)
#  define CREST_VISIBLE __attribute__((visibility("default")))
#else
#  define CREST_VISIBLE // no annotation; isa<T>() may be unsafe across DSOs
#endif

namespace crest {

// CrestObject — base for all CREST-managed foreign objects.
// The deletor function pointer at offset 0 serves dual purpose:
//   1. Destructor: called by with-CrestObject on exit to free the object
//   2. Type tag:   compare the deletor address to identify the concrete type
//
// To make your class a CrestObject, inherit from AsCrest<YourClass>:
//   struct CMyObj : public AsCrest<CMyObj> { ... };
//
// Layout:
//   offset 0: deletor (8B) — function pointer, filled in by AsCrest<T>
struct CrestObject {
  void (*deletor)(void* self);

  // Type predicate: is this CrestObject* actually a T*?
  // Defined after AsCrest<T> (requires AsCrest<T> to be complete).
  template <typename T> bool isa() const;
}; // struct CrestObject

// CRTP mixin: inheriting from AsCrest<T> automatically fills in the deletor.
// type_deletor is a plain static function whose address is the runtime type
// tag for T — unique and stable per instantiation.
template <typename T> struct AsCrest : public CrestObject {
  // Public: needed by CrestObject::isa<T>() for comparison.
  // CREST_VISIBLE forces default visibility — on ELF (Linux/macOS), ld.so
  // unifies weak default-visibility symbols across DSO boundaries so the
  // function pointer comparison in isa<T>() remains valid.
  // On MSVC/Windows, CREST_VISIBLE is empty: the PE/COFF loader does NOT
  // unify weak template instantiations across DLL boundaries — each DLL keeps
  // its own copy of type_deletor at a different address, so isa<T>() is
  // unsafe when comparing objects that originated from different DLLs.
  CREST_VISIBLE static void type_deletor(void* self) {
    delete static_cast<T*>(self);
  }

  AsCrest() : CrestObject{type_deletor} {}

  // Checked downcast from the raw address Scheme passes: nullptr when the
  // address is 0 or its type tag is not T's. The null test is on the integer,
  // so it is well-defined (a null `this` is undefined behavior and compilers
  // delete such tests).
  static T* checked(uint64_t addr) {
    if (!addr) {
      return nullptr;
    }
    auto* obj = reinterpret_cast<CrestObject*>(addr);
    return obj->isa<T>() ? static_cast<T*>(obj) : nullptr;
  }
};

// Deferred definition at namespace scope — requires AsCrest<T> to be complete.
// Cannot be defined inside AsCrest<T>'s body (out-of-class definitions must
// be at namespace scope, not nested inside another class).
template <typename T> inline bool CrestObject::isa() const {
  return deletor == AsCrest<T>::type_deletor;
}

// CrestBox<T> — heap-allocates T by value inside a CrestObject shell.
// The AsCrest<CrestBox<T>> type_deletor frees the whole struct (including T).
// Use for objects that CREST creates and owns:
//   OperationState, RewritePatternSet, TypeConverter, ConversionTarget,
//   OpBuilder.
// inner() reaches the boxed T of a typed shell; the static inner(addr, who)
// first verifies that a raw address from Scheme really is a CrestBox<T>:
// the boxed T, or nullptr.
template <typename T> struct CrestBox : public AsCrest<CrestBox<T>> {
  template <typename... Args>
  explicit CrestBox(Args&&... args)
      : AsCrest<CrestBox<T>>(), value_(std::forward<Args>(args)...) {}
  T& inner() { return value_; }
  const T& inner() const { return value_; }
  static T* inner(uint64_t addr) {
    auto* box = AsCrest<CrestBox<T>>::checked(addr);
    return box ? &box->value_ : nullptr;
  }

private:
  T value_;
};

// CrestBox<T*> — a shell holding a T* it does not own: the deletor frees only
// the shell, T lives elsewhere. Use for objects MLIR owns and passes into
// callbacks (e.g. RewriterBase in patterns, whose destructor is protected, so
// CrestBox<RewriterBase> cannot exist). inner() dereferences, so it returns
// T* exactly like CrestBox<T>::inner(addr). A raw pointer can therefore never
// be boxed by value.
template <typename T> struct CrestBox<T*> : public AsCrest<CrestBox<T*>> {
  explicit CrestBox(T* p) : AsCrest<CrestBox<T*>>(), ptr_(p) {}
  T& inner() const { return *ptr_; }
  static T* inner(uint64_t addr) {
    auto* box = AsCrest<CrestBox<T*>>::checked(addr);
    return box ? box->ptr_ : nullptr;
  }

private:
  T* ptr_;
};

// A T* from either kind of shell a Scheme program can hold for T: the
// CrestBox<T> it made itself or the CrestBox<T*> that borrows an object MLIR
// owns (as the pattern set a dialect's :get-canonicalization-patterns hook
// receives), or nullptr.
template <typename T> T* as_ref(uint64_t addr) {
  if (addr && reinterpret_cast<CrestObject*>(addr)->isa<CrestBox<T*>>()) {
    return CrestBox<T*>::inner(addr);
  }
  return CrestBox<T>::inner(addr);
}

void registerCrestObjectBindings();

} // namespace crest
