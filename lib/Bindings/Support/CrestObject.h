#pragma once

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
//   2. Type tag:   compare the deletor address to identify the concrete
//   type
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
};

// Deferred definition at namespace scope — requires AsCrest<T> to be complete.
// Cannot be defined inside AsCrest<T>'s body (out-of-class definitions must
// be at namespace scope, not nested inside another class).
template <typename T> inline bool CrestObject::isa() const {
  return deletor == AsCrest<T>::type_deletor;
}
} // namespace crest
namespace crest {
void registerCrestObjectBindings();
}
